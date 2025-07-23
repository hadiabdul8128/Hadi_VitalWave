import pandas as pd
from datetime import datetime

def calculate_duration(file_path):
    """
    Calculates the duration in seconds between the first and last timestamp in the isodate column.
    
    Arguments:
        file_path (str): Path to the CSV file.
        
    Returns:
        float: Duration in seconds between first and last timestamp.
    """
    # Read the CSV file
    df = pd.read_csv(file_path)
    
    # Convert the 'isodate' column to datetime
    df['isodate'] = pd.to_datetime(df['isodate'], errors='coerce')
    
    # Drop any rows where 'isodate' conversion failed
    df = df.dropna(subset=['isodate'])
    
    # Get the first and last timestamps
    start_time = df['isodate'].iloc[0]
    end_time = df['isodate'].iloc[-1]
    
    # Calculate the duration in seconds
    duration_seconds = (end_time - start_time).total_seconds()
    
    return duration_seconds

# Define the file path
# file_path = '/Users/sjtok/bc_infection/wearable-data-science/new_pipeline/minute/2024-11-05T23_09_04.818Z.csv'
file_path ='/Users/sjtok/bc_infection/wearable-data-science/new_pipeline/minute/2024-11-05T23_07_42.238Z.csv'


# Calculate and print the duration in seconds
duration_seconds = calculate_duration(file_path)
print(f"Duration of the CSV file in seconds: {duration_seconds}")
