import os
import pandas as pd
from datetime import timedelta
import logging


def combine_dfs(directory):
    """
    Combines multiple CSV files from the specified directory into a single dataframe.
    
    Parameters:
    -----------
    directory: String
        Directory containing CSV files.

    Returns:
    -----------
    pandas.DataFrame
        Combined dataframe sorted by the timestamp (isodate).
    """
    all_data_frames = []

    for filename in os.listdir(directory):
        if filename.endswith('.csv'):
            file_path = os.path.join(directory, filename)
            df = pd.read_csv(file_path)
            all_data_frames.append(df)

    combined_df = pd.concat(all_data_frames, ignore_index=True)
    combined_df = combined_df.sort_values(by='isodate')
    
    return combined_df

def filter(df, col):
    """
    Filters a dataframe by removing rows with null values in the specified columns.
    
    Parameters:
    -----------
    df : pandas.DataFrame
    col : list
        List of columns to retain.
    
    Returns:
    -----------
    pandas.DataFrame
        Filtered dataframe with non-null values for the specified columns.
    """
    df_filtered = df.dropna(subset=col)
    return df_filtered

def find_sample_cnt(df_filtered):
    """
    Calculates sample rates within the dataframe by counting the number of records per second.

    Parameters:
    -----------
    df_filtered: pandas.DataFrame
        The dataframe with filtered non-null values.

    Returns:
    -----------
    dict
        A dictionary containing the sample count per second, with timestamp keys.
    """
    # Ensure 'isodate' is present
    if 'isodate' not in df_filtered.columns:
        raise KeyError("'isodate' column is missing from the dataframe.")

    # Convert 'isodate' to datetime, coercing errors to NaT
    df_filtered['isodate'] = pd.to_datetime(df_filtered['isodate'], errors='coerce')

    # Drop rows with NaT in 'isodate'
    initial_count = len(df_filtered)
    df_filtered = df_filtered.dropna(subset=['isodate'])
    final_count = len(df_filtered)
    dropped_rows = initial_count - final_count
    if dropped_rows > 0:
        logging.warning(f"Dropped {dropped_rows} rows due to invalid 'isodate' values.")

    if df_filtered.empty:
        logging.error("No valid 'isodate' entries found after conversion. Cannot calculate sampling rates.")
        return {}

    # Set 'isodate' as index for efficient resampling
    df_filtered = df_filtered.set_index('isodate')

    # Resample per second and count the number of samples
    samples_per_second_series = df_filtered.resample('S').size()

    # Convert to dictionary with formatted time strings
    samples_per_second = {}
    for timestamp, count in samples_per_second_series.items():
        milliseconds = timestamp.strftime('%f')[:3]
        time_str = timestamp.strftime(f'%H:%M:%S.{milliseconds}')
        samples_per_second[time_str] = count

    return samples_per_second
