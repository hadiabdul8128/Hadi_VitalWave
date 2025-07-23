from datetime import datetime, timezone, timedelta
import pandas as pd
import os
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import resample, butter, filtfilt

def combine_dfs(directory):
    """
    Helper function for process_timestamps_ppg
    Takes in a directory path of device data files (ideally from the same date) and combines it into one dataframe
    Parameters
    -----------
    directory: String, audio files path

    Returns
    -------
    accel_mag: acceleration magnitude vector (array)
    """
    all_data_frames = []
    
    # Iterate over all files in the directory
    for filename in os.listdir(directory):
        # Check if the file is a CSV
        if filename.endswith('.csv'):
            file_path = os.path.join(directory, filename)
            # Read the CSV file into a DataFrame
            df = pd.read_csv(file_path)
            all_data_frames.append(df)
    
    # Concatenate all DataFrames
    combined_df = pd.concat(all_data_frames, ignore_index=True)

    # Sort in chronological order
    combined_df = combined_df.sort_values(by='Timestamp')
    
    return combined_df

def process_timestamps_ppg(path):
    df = combine_dfs(path)
    df['Timestamp'] = pd.to_datetime(df['Timestamp'], utc=True)
    df['Timestamp'] = pd.to_datetime(df['Timestamp']).dt.strftime('%Y-%m-%d %H:%M:%S.%f UTC')
    return df

def splice_df_ppg(df, intervals):
    spliced_dfs = {}
    df2 = df.copy()
    df2['Timestamp'] = pd.to_datetime(df2['Timestamp'])
    for label, (start, end) in intervals.items():
        start_time = pd.to_datetime(start)
        end_time = pd.to_datetime(end)
        spliced_dfs[label] = df2[(df2['Timestamp'] >= start_time) & (df2['Timestamp'] <= end_time)]

        # Steps is too short, need to find out a way to handle
    return spliced_dfs

def determine_sampling_rate(df_original, time_column='Timestamp', save_to_file=False, dir=None):
    df = df_original.copy()

    # Ensure the time_column is in datetime format
    df[time_column] = pd.to_datetime(df[time_column], errors='coerce')

    # Calculate differences between consecutive timestamps
    df['Time Difference'] = df[time_column].diff()

    # Remove the first NaN value
    differences = df['Time Difference'].dropna()

    # Find the median  time difference
    median_difference = differences.median()

    # Convert timedelta to total seconds
    seconds = median_difference.total_seconds()
    if seconds == 0:
        print("The time difference is zero, which is not valid for determining frequency.")
        return None

    # Calculate frequency in Hz
    frequency_hz = 1 / seconds

    # Calculate differences between consecutive timestamps
    df['Time Difference'] = df[time_column].diff().fillna(pd.Timedelta(seconds=0))
    
    # Convert Timedelta to total seconds
    df['Time Difference in Seconds'] = df['Time Difference'].dt.total_seconds()
    
    # Exclude zero or negative values that may result from incorrect data
    valid_differences = df['Time Difference in Seconds'][df['Time Difference in Seconds'] > 0]
    
    # Convert time differences to frequencies (Hz)
    frequencies = 1 / valid_differences
    
    # Box plot of the frequencies to visualize the distribution of sampling rates
    # plt.figure(figsize=(10, 6))
    # plt.boxplot(frequencies, vert=False)
    # plt.title('Box Plot of Sampling Rates')
    # plt.xlabel('Frequency (Hz)')
    # plt.gca().set_yticklabels(['Sampling Rate'])

    # if save_to_file:
    #     plt.savefig(f'{dir}_sampling_rate_boxplot_{datetime.now()}.png')

    # plt.show()

    # Print or return the sampling rate in Hz
    #print(f"The median sampling rate is {frequency_hz:.2f} Hz.")
    return frequency_hz


# try not dropping na values and see what happens
def filter(df, col):
    """
    Takes in a combined dataframe to filter by desired columns

    Parameters
    -----------
    df: pandas df
        combined dataframe 
    col: array
        subset to filter by

    Returns
    -----------
    df_filtered: clean dataframe with non-n/a values for our variables of interest (in col)

    Example use: filter(df, ['acc_x', 'acc_y', 'acc_z']) -> dataframe with non-n/a acceleration values
    """
    df_filtered = df.dropna(subset=col)
    return df_filtered

def remove_outliers_iqr(df, column):
    """
    Removes outliers based on the IQR method for a specific column in the dataframe.
    """
    Q1 = df[column].quantile(0.25)
    Q3 = df[column].quantile(0.75)
    IQR = Q3 - Q1
    lower_bound = Q1 - 1.5 * IQR
    upper_bound = Q3 + 1.5 * IQR
    return df[(df[column] >= lower_bound) & (df[column] <= upper_bound)]

def iqr_filter_window(df, column, window_size=500):
    """
    Applies IQR filtering in a sliding window approach to a specified column in the dataframe.
    """
    cleaned_data = []
    num_points = len(df)
    
    for start in range(0, num_points, window_size):
        end = start + window_size
        window = df.iloc[start:end]
        
        # Calculate IQR for the current window
        q1 = window[column].quantile(0.25)
        q3 = window[column].quantile(0.75)
        iqr = q3 - q1
        lower_bound = q1 - 1.5 * iqr
        upper_bound = q3 + 1.5 * iqr
        
        # Remove outliers for the window
        window_cleaned = window[(window[column] >= lower_bound) & (window[column] <= upper_bound)]
        cleaned_data.append(window_cleaned)
    
    # Concatenate cleaned data from all windows
    cleaned_df = pd.concat(cleaned_data).reset_index(drop=True)
    return cleaned_df


def bandpass_filter(
        sig: np.ndarray,
        fs: int,
        lowcut: float,
        highcut: float,
        order: int=2
) -> np.ndarray:
    """
    Apply a bandpass filter to the input signal.

    Args:
        sig (np.ndarray): The input signal.
        fs (int): The sampling frequency of the input signal.
        lowcut (float): The low cutoff frequency of the bandpass filter.
        highcut (float): The high cutoff frequency of the bandpass filter.

    Return:
        sig_filtered (np.ndarray): The filtered signal using a Butterworth bandpass filter.
    """
    nyquist = 0.5 * fs
    low = lowcut / nyquist
    high = highcut / nyquist
    b, a = butter(order, [low, high], btype='band')
    sig_filtered = filtfilt(b, a, sig)
    return sig_filtered

def filter_all(df, lowcut, highcut, order=2, window_size=500):
    """
    Apply IQR filter and then bandpass filter to the PPG data.
    """
    channels = ['ppg_ir', 'ppg_r', 'ppg_g', 'ppg_b']
    
    # Apply IQR filter to remove outliers
    for chan in channels:
        df = iqr_filter_window(df, chan, window_size=window_size)
    
    # After IQR filtering, apply the bandpass filter
    df_dropped = filter(df, channels)
    
    # Get the sampling frequency
    fs = determine_sampling_rate(df_dropped, time_column="Timestamp")
    print(f"Sampling frequency: {fs} Hz")

    # Apply bandpass filter to each channel
    for chan in channels:
        df_dropped[f"{chan}_filtered"] = bandpass_filter(df_dropped[chan].values, fs, lowcut, highcut, order)

    return df_dropped


def plot_and_comp(df):
    channels = ['ppg_ir', 'ppg_r', 'ppg_g', 'ppg_b']
    for chan in channels:
        orig = df[chan].values
        filt = df[f"{chan}_filtered"].values
        plt.plot(orig, "pink")
        plt.plot(filt, "violet")
        plt.xlabel("non-n/a data points")
        plt.ylabel("PPG")
        plt.title(f"{chan} original vs filtered")
        plt.show()

# # Example usage
# ppg_df = combine_dfs("data/11_12_2024/BassWearable")
# #print(ppg_df)
# butterworth_filtered = filter_all(ppg_df, lowcut=0.5, highcut=3)
# print(butterworth_filtered)
# # Un-comment to check
# plot_and_comp(butterworth_filtered)
# #print(butterworth_filtered)
