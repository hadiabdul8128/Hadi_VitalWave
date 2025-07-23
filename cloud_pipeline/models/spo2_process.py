import pandas as pd
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def preprocess_spo2_csv(directory, start_timestamp, end_timestamp):
    """
    Preprocesses multiple SpO2 CSV files across all subjects, merges them, and filters unnecessary rows.
    
    Arguments:
        directory (str): Directory containing the SpO2 CSV files.
        start_timestamp (int): The starting timestamp for filtering data.
        end_timestamp (int): The ending timestamp for filtering data.
    
    Returns:
        pd.DataFrame: Combined DataFrame with filtered data across all subjects.
    """
    all_data_frames = []
    
    for filename in os.listdir(directory):
        if filename.endswith('.csv'):
            file_path = os.path.join(directory, filename)
            try:
                # Read the CSV file, skip repeated header rows, and use the first header row
                df = pd.read_csv(file_path, header=0)
                
                # Ensure there are no duplicate header rows
                if df.empty:
                    logging.warning(f"Skipped empty file: {file_path}")
                    continue

                # Filter rows based on the provided timestamps (ensure timestamps are within the range)
                df['Timestamp'] = pd.to_datetime(df['Timestamp'], errors='coerce')
                df = df[(df['Timestamp'].astype(int) >= start_timestamp) & (df['Timestamp'].astype(int) <= end_timestamp)]

                if df.empty:
                    logging.warning(f"No valid rows found for timestamps in file: {file_path}")
                    continue
                
                # Add this subject's data to the list of data frames
                all_data_frames.append(df)
                logging.info(f"Successfully processed {file_path}")
            
            except Exception as e:
                logging.error(f"Error processing file {file_path}: {e}")

    if not all_data_frames:
        logging.error("No valid CSV files found or all files failed to process.")
        return pd.DataFrame()
    
    # Combine all the individual data frames into one
    combined_df = pd.concat(all_data_frames, ignore_index=True)
    
    # Remove duplicate header rows (if any)
    combined_df.drop_duplicates(subset=['Session', 'Index', 'Timestamp'], keep='first', inplace=True)
    
    return combined_df

if __name__ == "__main__":
    # Specify the directory containing SpO2 CSV files and the timestamps to filter data
    directory_path = "/Users/sjtok/bc_infection/wearable-data-science/data/11_19_2024/SPO2"
    start_timestamp = 1732058574  # Specify the start timestamp for the required section
    end_timestamp = 1732058874  # Specify the end timestamp for the required section
    
    # Preprocess the SpO2 data and merge it into a single DataFrame
    df = preprocess_spo2_csv(directory_path, start_timestamp, end_timestamp)
    
    if df.empty:
        logging.error("Preprocessed data is empty. Exiting.")
    else:
        logging.info("Successfully processed and merged all SpO2 CSV files.")
        # You can now proceed with using df for training your models.
    
    # Specify the output file path
    output_file_path = "/Users/sjtok/bc_infection/wearable-data-science/data/11_19_2024/SPO2/preprocessed/merged_spo2.csv"

    # Output the final DataFrame to a CSV file
    df.to_csv(output_file_path, index=False)

    logging.info(f"Final preprocessed data has been saved to {output_file_path}")

