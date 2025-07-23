import io
import logging
import functions_framework
import pandas as pd
from biomarkers_minute import calculate_metrics_per_minute
from datetime import datetime, timedelta, timezone  # Updated import
import json
import base64
from firebase_admin import firestore, storage, initialize_app

# Set UTC-5 timezone
est = timezone(timedelta(hours=-5))  # Adjusting for UTC-5 timezone

# Initialize Firebase Admin SDK with default credentials
initialize_app()
db = firestore.client()

# Configure logging
logging.basicConfig(level=logging.INFO)

# Constants
BATCH_SIZE = 2  # currently one csv is around 3 mins
BATCH_TIMEOUT = timedelta(minutes=9)  # Set a 9-minute timeout for pending batches

# Helper function to process CSV files in a batch
def process_files(file_batch, db, userID, deviceID):
    
    # ***** Test Firestore write access by adding a dummy document
    test_doc_ref = db.collection('demo_data').document('dummy_test_document')
    try:
        test_doc_ref.set({
        "timestamp": datetime.now(timezone.utc),  # Updated to use datetime and timezone from the correct module
        "message": "This is a test document to verify Firestore write access."
        })

        logging.info("Successfully created a dummy document in Firestore.")
    except Exception as e:
        logging.error(f"Failed to create dummy document in Firestore: {e}")

    combined_data = []
    for file_info in file_batch:
        bucket_name = file_info["bucket"]
        file_name = file_info["file_name"]
        try:
            bucket = storage.bucket(bucket_name)
            blob = bucket.blob(file_name)
            content = blob.download_as_text()
            df = pd.read_csv(io.StringIO(content))
            combined_data.append(df)
            logging.info(f"Successfully downloaded and parsed {file_name}.")
        except Exception as e:
            logging.error(f"Failed to download or parse {file_name}: {e}")
            continue  # Skip this file and proceed with others

    if not combined_data:
        logging.warning("No valid data found in the batch to process.")
        return

    # Concatenate and process data
    combined_df = pd.concat(combined_data, ignore_index=True)
    try:
        df_upload = calculate_metrics_per_minute(combined_df)
        logging.info("Successfully calculated metrics per minute.")
    except Exception as e:
        logging.error(f"Failed to calculate metrics per minute: {e}")
        return

    if df_upload.empty:
        logging.warning("Aggregated data is empty. Skipping Firestore upload.")
        return

    # Firestore upload process with batch size limit
    user_doc_ref = db.collection('demo_data').document(userID)
    device_doc_ref = user_doc_ref.collection(deviceID)  # Reference to the device subcollection

    # Check if deviceID already exists in Firestore document
    user_data = user_doc_ref.get().to_dict() or {}
    device_exists = any(value == deviceID for key, value in user_data.items() if key.startswith("deviceID"))

    if not device_exists:
        device_count = sum(key.startswith("deviceID") for key in user_data)
        device_field_key = f"deviceID{device_count + 1}"
        user_doc_ref.set({device_field_key: deviceID}, merge=True)

    # Set up 'minute', 'hour', and 'day' documents with dummy fields if they don't already exist
    try:
        # Create a dummy field in 'minute' document
        minute_doc_ref = device_doc_ref.document("minute")
        if not minute_doc_ref.get().exists:
            minute_doc_ref.set({"dummy_field": "initialize"}, merge=True)

        # Create 'hour' and 'day' documents with dummy fields
        hour_doc_ref = device_doc_ref.document("hour")
        if not hour_doc_ref.get().exists:
            hour_doc_ref.set({"dummy_field": "initialize"}, merge=True)

        day_doc_ref = device_doc_ref.document("day")
        if not day_doc_ref.get().exists:
            day_doc_ref.set({"dummy_field": "initialize"}, merge=True)

    except Exception as e:
        logging.error(f"Failed to initialize 'minute', 'hour', or 'day' document: {e}")

    # Initialize batch
    batch = db.batch()
    batch_size_limit = 500
    batch_count = 0

    try:
        for index, row in df_upload.iterrows():
            row_dict = row.to_dict()
            timestamp = row_dict.get("timestamp")

            # Ensure timestamp is a datetime object and convert to UTC-5
            if isinstance(timestamp, datetime):
                timestamp = timestamp.astimezone(est)
            else:
                logging.warning(f"Invalid timestamp in row {index}. Skipping.")
                continue

            # Set Firestore document path and data in UTC-5
            date_str = timestamp.strftime('%m-%d-%Y')
            time_str = timestamp.strftime('%H:%M:%S')

            # Reference to the date collection and minute-level document
            date_collection_ref = minute_doc_ref.collection(date_str)
            time_doc_ref = date_collection_ref.document(time_str)

            # Fetch existing document to avoid overwriting non-NaN values
            existing_data = time_doc_ref.get().to_dict() if time_doc_ref.get().exists else {}

            # Update only non-NaN values
            updated_data = {key: value for key, value in row_dict.items() if pd.notna(value)}
            if existing_data:
                for key, value in updated_data.items():
                    if pd.notna(value):
                        existing_data[key] = value
                updated_data = existing_data  # Only non-NaN fields overwrite existing data

            updated_data['timestamp'] = timestamp  # Firestore will accept this directly

            batch.set(time_doc_ref, updated_data, merge=True)
            batch_count += 1

            # Commit batch if limit reached
            if batch_count >= batch_size_limit:
                batch.commit()
                logging.info(f"Committed a batch of {batch_count} documents to Firestore.")
                batch = db.batch()  # Start a new batch
                batch_count = 0

    except Exception as e:
        logging.error(f"Failed to upload data to Firestore: {e}")

    finally:
        # Commit remaining documents in the final batch
        if batch_count > 0:
            batch.commit()
            logging.info(f"Committed final batch of {batch_count} documents to Firestore.")

@functions_framework.cloud_event
def pubsub_trigger(cloud_event):
    batch_ref = db.collection("file_batches").document("current_batch")
    batch_data = batch_ref.get().to_dict() or {}
    batch_data.setdefault("files", [])
    batch_data.setdefault("start_time", datetime.now(timezone.utc).isoformat())  # Updated

    # Parse and decode the Pub/Sub message
    try:
        message_data = cloud_event.data.get("message", {}).get("data")
        if not message_data:
            logging.error("No data field in Pub/Sub message.")
            return

        # Decode and parse JSON
        message_json = base64.b64decode(message_data).decode("utf-8")
        message = json.loads(message_json)
        bucket_name = message["bucket"]
        file_name = message["file_name"]
        logging.info(f"Received file {file_name} from bucket {bucket_name}")
    
    except Exception as e:
        logging.error(f"Error decoding Pub/Sub message: {e}")
        return

    # Add file to batch and update start time if not already set
    batch_data["files"].append({"bucket": bucket_name, "file_name": file_name})
    if not batch_data.get("start_time"):
        batch_data["start_time"] = datetime.now(timezone.utc).isoformat()  # Updated

    batch_ref.set(batch_data)

    # Check if batch size or timeout is reached
    current_time = datetime.now(timezone.utc)  # Updated
    start_time = datetime.fromisoformat(batch_data["start_time"])
    
    if len(batch_data["files"]) >= BATCH_SIZE or current_time - start_time >= BATCH_TIMEOUT:
        logging.info(f"Processing batch. Batch size: {len(batch_data['files'])} files")

        # Extract userID and deviceID from filename path
        file_path_parts = file_name.split('/')
        if len(file_path_parts) < 3:
            logging.error(f"File path {file_name} does not have enough parts to extract userID and deviceID.")
            return
        userID = file_path_parts[-3]
        deviceID = file_path_parts[-2]

        # Process the files in the batch
        process_files(batch_data["files"], db, userID, deviceID)

        # Clear the batch data in Firestore
        batch_ref.set({"files": [], "start_time": None})
