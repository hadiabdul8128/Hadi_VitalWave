import functions_framework
from google.cloud import pubsub_v1
import json
import os
import logging

# Initialize logging
logging.basicConfig(level=logging.INFO)

# Initialize Pub/Sub publisher client
publisher = pubsub_v1.PublisherClient()

# Fetch environment variables
gcp_project = os.getenv("GCP_PROJECT")
if not gcp_project:
    logging.error("GCP_PROJECT environment variable is not set.")
    raise EnvironmentError("GCP_PROJECT environment variable is required.")

topic_name = "csv-upload-topic"
topic_path = publisher.topic_path(gcp_project, topic_name)
logging.info(f"Publishing to topic: {topic_path}")

TARGET_BUCKET = "bc-infection-detection.appspot.com"  # Set your target bucket name here

@functions_framework.cloud_event
def storage_to_pubsub(cloud_event):
    try:
        # Extract bucket and file name from the event
        bucket = cloud_event.data.get("bucket")
        file_name = cloud_event.data.get("name")
        logging.info(f"Received event for file: {file_name} in bucket: {bucket}")

        # Only proceed if the file is a CSV and from the specific bucket
        if bucket != TARGET_BUCKET:
            logging.info(f"Skipped file from different bucket: {bucket}")
            return
        if not file_name.endswith('.csv'):
            logging.info(f"Skipped non-CSV file: {file_name}")
            return

        # Construct the message with bucket and file name
        message = {
            "bucket": bucket,
            "file_name": file_name
        }
        
        # Publish message to Pub/Sub topic
        future = publisher.publish(topic_path, json.dumps(message).encode("utf-8"))
        message_id = future.result()  # Ensure the message is published
        logging.info(f"Published message ID: {message_id} for CSV file {file_name} in bucket {bucket}")

    except Exception as e:
        logging.error(f"Error in storage_to_pubsub function: {e}")
        raise e
