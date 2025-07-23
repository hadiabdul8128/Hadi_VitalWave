import numpy as np
import pandas as pd
import os
import logging
from scipy.signal import find_peaks
from datetime import timedelta
import neurokit2 as nk
from sklearn.linear_model import Lasso, Ridge
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error
import matplotlib.pyplot as plt

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def merge_ground_truth(ppg_directory, ground_truth_file):
    """
    Merges the ground truth SpO2 data with the PPG data into a single DataFrame.
    
    Arguments:
        ppg_directory (str): Directory containing CSV files for raw PPG data
        ground_truth_file (str): CSV file containing the ground truth SpO2 values

    Returns:
        pd.DataFrame: Combined DataFrame with both PPG and ground truth SpO2 values
    """
    # Load the ground truth data
    ground_truth_df = pd.read_csv(ground_truth_file)
    ground_truth_df['isodate'] = pd.to_datetime(ground_truth_df['isodate'])

    # Combine PPG data
    df = combine_dfs(ppg_directory)
    
    # Merge ground truth with PPG data based on 'isodate'
    df = pd.merge(df, ground_truth_df[['isodate', 'ground_truth_spo2']], on='isodate', how='left')

    return df

def combine_dfs(directory):
    """
    Combines all CSV files in a directory into a single DataFrame.
    
    Arguments:
        directory (str): directory containing CSV files

    Returns:
        pd.DataFrame: concatenated DataFrame of all CSVs sorted by isodate column
    """
    all_data_frames = []
    
    # List of columns to keep
    columns_to_keep = ['isodate', 'acc_x', 'acc_y', 'acc_z', 'gyro_x', 'gyro_y', 'gyro_z', 'mag_x', 'mag_y', 'mag_z', 'ppg_r', 'ppg_b', 'ppg_ir', 'ppg_g']
    
    # Iterate over all files in the directory
    for filename in os.listdir(directory):
        if filename.endswith('.csv'):
            file_path = os.path.join(directory, filename)
            try:
                # Load the CSV and select only the required columns
                df = pd.read_csv(file_path, usecols=columns_to_keep)
                all_data_frames.append(df)
                logging.info(f"Successfully read {file_path}")
            except Exception as e:
                logging.error(f"Error reading {file_path}: {e}")
    
    if not all_data_frames:
        logging.error("No CSV files found or all files failed to read.")
        return pd.DataFrame()
    
    combined_df = pd.concat(all_data_frames, ignore_index=True)
    combined_df.sort_values(by='isodate', inplace=True)
    return combined_df

def find_sample_rate_per_minute(df):
    """
    Calculates the sample rate per minute based on the 'isodate' column.
    
    Arguments:
        df (pd.DataFrame): DataFrame containing collected PPG data

    Returns:
        dict: dictionary with timestamp as key and sample rate per minute as value.
    """
    df['isodate'] = pd.to_datetime(df['isodate'], errors='coerce')
    df = df.dropna(subset=['isodate'])

    if df.empty:
        logging.error("No valid 'isodate' entries found. Cannot calculate sample rates for SpO2.")
        return {}
    
    samples_per_minute = {}
    current_time = df['isodate'].min()
    
    while current_time <= df['isodate'].max(): 
        next_time = current_time + timedelta(minutes=1)
        sample_count = df[(df['isodate'] >= current_time) & (df['isodate'] < next_time)].shape[0]
        sample_rate = sample_count / 60 if sample_count > 0 else None
        samples_per_minute[current_time.floor('min')] = sample_rate
        current_time = next_time
    
    logging.info("Sample rates per minute calculated for SpO2.")
    return samples_per_minute

def resampling(signal, sampling_rate, desired_sampling_rate, method="FFT"):
    """
    Resamples signal using Neurokit's resampling function to calculate median sampling rate.

    Arguments:
        signal (array): Interpolated signal from last function.
        sampling_rate (int): Sampling rate of our signal.
        desired_sampling_rate (int): Sampling rate we sample up to.
        method (str): Choose from "interpolation", "numpy", "FFT". 

    Returns:
        array: resampled signal
    """
    return nk.signal_resample(signal=signal, sampling_rate=sampling_rate, desired_sampling_rate=desired_sampling_rate, method=method)

def calculate_ac_dc(signal, peaks, troughs):
    """
    Calculate the AC and DC components of the given signal based on its peaks and troughs.
    
    Arguments:
        signal (array-like): The raw PPG signal.
        peaks (array-like): Peak indices of the signal.
        troughs (array-like): Trough indices of the signal.
    
    Returns:
        tuple: (ac, dc) where 'ac' is the AC component and 'dc' is the DC component of the signal.
    """
    dc = np.mean(signal)  # DC component is the mean of the signal
    ac = 0

    min_len = min(len(peaks), len(troughs))
    
    if min_len == 0:
        return ac, dc  # If there are no peaks/troughs, return zero AC component and DC component
    
    # Calculate AC component as the average peak-to-trough difference
    for i in range(min_len):
        ac += (signal[peaks[i]] - signal[troughs[i]])
    
    ac = ac / min_len  # Average AC component
    
    return ac, dc

def calculate_r(df, channel_1, channel_2):
    """
    Calculate R ratio for a given pair of channels.

    Arguments:
        df (pd.DataFrame): The input DataFrame containing PPG signals.
        channel_1 (str): Name of the first channel.
        channel_2 (str): Name of the second channel.

    Returns:
        np.array: Array of R ratios for the given channels.
    """
    signal_1 = df[f'ppg_{channel_1}']
    signal_2 = df[f'ppg_{channel_2}']
    
    peaks_1, _ = find_peaks(signal_1, height=0, prominence=0.002)
    troughs_1, _ = find_peaks(-signal_1, height=-30000, prominence=0.002)
    
    peaks_2, _ = find_peaks(signal_2, height=0, prominence=0.002)
    troughs_2, _ = find_peaks(-signal_2, height=-30000, prominence=0.002)
    
    # Calculate AC and DC for both channels
    ac_1, dc_1 = calculate_ac_dc(signal_1, peaks_1, troughs_1)
    ac_2, dc_2 = calculate_ac_dc(signal_2, peaks_2, troughs_2)
    
    # Calculate R ratio
    r = (ac_1 / dc_1) / (ac_2 / dc_2)
    
    return r

def lasso_regression_k(df, channel_1, channel_2, ground_truth):
    r = calculate_r(df, channel_1, channel_2)
    X = r.reshape(-1, 1)  # Reshape for a single feature input
    y = df[ground_truth]  # Ground truth SpO2 values
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Apply Lasso Regression
    model = Lasso(alpha=0.1)  # Regularization strength
    model.fit(X_train, y_train)
    
    y_pred = model.predict(X_test)

    # Calculate SpO2 using the formula with the predicted k values
    k_estimated = model.coef_[0]
    spo2_pred = 100 * (1 - k_estimated * X_test.flatten())

    # Use Mean Absolute Error to evaluate the model
    mae = mean_absolute_error(y_test, spo2_pred)
    
    logging.info(f"Lasso Regression MAE: {mae}")
    logging.info(f"Estimated k for {channel_1} and {channel_2}: {k_estimated}")
    return k_estimated

def ridge_regression_k(df, channel_1, channel_2, ground_truth):
    r = calculate_r(df, channel_1, channel_2)
    X = r.reshape(-1, 1)  # Reshape for a single feature input
    y = df[ground_truth]  # Ground truth SpO2 values
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Apply Ridge Regression
    model = Ridge(alpha=1.0)  # Regularization strength
    model.fit(X_train, y_train)
    
    y_pred = model.predict(X_test)

    # Calculate SpO2 using the formula with the predicted k values
    k_estimated = model.coef_[0]
    spo2_pred = 100 * (1 - k_estimated * X_test.flatten())

    # Use Mean Absolute Error to evaluate the model
    mae = mean_absolute_error(y_test, spo2_pred)
    
    logging.info(f"Ridge Regression MAE: {mae}")
    logging.info(f"Estimated k for {channel_1} and {channel_2}: {k_estimated}")
    return k_estimated

def spo2_per_minute_func(data, k_values): 
    """
    Calculates SpO2 percentage for each minute in the dataset based on red, green, and IR signals.
    
    Parameters:
        data (pd.DataFrame): DataFrame containing collected PPG data.
        k_values (dict): Dictionary of k-values for each channel combination.
        
    Returns:
        pd.DataFrame: DataFrame with minute-level timestamps to SpO2 percentage for each minute.
    """
    data['timestamp'] = pd.to_datetime(data['isodate']).dt.floor('min')  
    data_grouped = data.groupby('timestamp').size().reset_index(name='count')
    logging.info("Data grouped by timestamp.")

    sample_rates = find_sample_rate_per_minute(data)
    if not sample_rates:
        logging.error("Sample rates dictionary is empty for SpO2. Exiting function.")
        return pd.DataFrame()

    spo2_per_minute = {}
    previous_mins = 0
    
    # Loop through each minute group in the data
    for _, row in data_grouped.iterrows(): 
        timestamp = row['timestamp']
        current_mins = row['count']
        
        sample_rate_per_minute = sample_rates.get(timestamp)
        if sample_rate_per_minute is None or np.isnan(sample_rate_per_minute):
            logging.warning(f"Sample rate for timestamp {timestamp} is NaN or missing. Skipping.")
            previous_mins += current_mins
            continue
        
        signal_red = np.array(data.ppg_r[previous_mins:previous_mins + current_mins].dropna())
        signal_ir = np.array(data.ppg_ir[previous_mins:previous_mins + current_mins].dropna())
        signal_green = np.array(data.ppg_g[previous_mins:previous_mins + current_mins].dropna())
        
        if len(signal_red) == 0 or len(signal_ir) == 0 or len(signal_green) == 0:
            logging.warning(f"No data for timestamp {timestamp}. Skipping.")
            previous_mins += current_mins
            continue
        
        ideal_sample_rate_red = np.nanmedian(signal_red)
        ideal_sample_rate_ir = np.nanmedian(signal_ir)
        ideal_sample_rate_green = np.nanmedian(signal_green)  
        
        if np.isnan(ideal_sample_rate_red) or np.isnan(ideal_sample_rate_ir) or np.isnan(ideal_sample_rate_green):
            logging.warning(f"NaN detected in ideal sample rates for {timestamp}. Skipping.")
            previous_mins += current_mins
            continue

        try:
            resampled_signal_red = resampling(signal_red, sample_rate_per_minute, ideal_sample_rate_red, method="FFT")
            resampled_signal_ir = resampling(signal_ir, sample_rate_per_minute, ideal_sample_rate_ir, method="FFT")
            resampled_signal_green = resampling(signal_green, sample_rate_per_minute, ideal_sample_rate_green, method="FFT")
            logging.info(f"Resampled signals for {timestamp}.")
        except Exception as e:
            logging.error(f"Resampling failed for timestamp {timestamp}: {e}")
            previous_mins += current_mins
            continue
        
        try:
            peaks_red, _ = find_peaks(resampled_signal_red, height=0, prominence=0.002)
            peaks_ir, _ = find_peaks(resampled_signal_ir, height=0, prominence=0.002)
            peaks_green, _ = find_peaks(resampled_signal_green, height=0, prominence=0.002)
            
            troughs_red, _ = find_peaks(-resampled_signal_red, height=-30000, prominence=0.002)
            troughs_ir, _ = find_peaks(-resampled_signal_ir, height=-30000, prominence=0.002)
            troughs_green, _ = find_peaks(-resampled_signal_green, height=-30000, prominence=0.002)
        except Exception as e:
            logging.error(f"Peak/trough detection failed for timestamp {timestamp}: {e}")
            previous_mins += current_mins
            continue
        
        previous_mins += current_mins
        
        try:
            # Use the predicted k values for each combination to calculate SpO2
            k_red_ir = k_values['red/IR']
            k_green_ir = k_values['green/IR']
            k_green_red = k_values['green/red']

            spo2_red_ir = 100 - (k_red_ir * (resampled_signal_red / resampled_signal_ir))
            spo2_green_ir = 100 - (k_green_ir * (resampled_signal_green / resampled_signal_ir))
            spo2_green_red = 100 - (k_green_red * (resampled_signal_green / resampled_signal_red))

            # Average the SpO2 values from each combination (you can choose to weight them differently)
            spo2_avg = (spo2_red_ir + spo2_green_ir + spo2_green_red) / 3
            spo2_per_minute[timestamp] = round(spo2_avg, 6)
        except Exception as e:
            logging.error(f"SpO2 calculation failed for timestamp {timestamp}: {e}")
            continue

    df = pd.DataFrame(list(spo2_per_minute.items()), columns=["timestamp", "spo2"])
    df.loc[df["spo2"] < 89.5, "spo2"] = np.nan
    
    return df 


if __name__ == "__main__":
    ppg_directory_path = "/Users/sjtok/bc_infection/wearable-data-science/data/11_12_2024/BassWearable"
    ground_truth_file = "/Users/sjtok/bc_infection/wearable-data-science/data/11_12_2024/SPO2/0_Seijung Kim_11_14_24.csv"
    
    # Load the data and merge with ground truth SpO2
    df = merge_ground_truth(ppg_directory_path, ground_truth_file)
    
    if df.empty:
        logging.error("Combined DataFrame is empty for SpO2. Exiting.")
    else:
        # Example usage of Lasso and Ridge regression models to estimate k
        k_red_ir_lasso = lasso_regression_k(df, 'red', 'IR', 'ground_truth_spo2')
        k_green_ir_lasso = lasso_regression_k(df, 'green', 'IR', 'ground_truth_spo2')
        k_green_red_lasso = lasso_regression_k(df, 'green', 'red', 'ground_truth_spo2')

        k_red_ir_ridge = ridge_regression_k(df, 'red', 'IR', 'ground_truth_spo2')
        k_green_ir_ridge = ridge_regression_k(df, 'green', 'IR', 'ground_truth_spo2')
        k_green_red_ridge = ridge_regression_k(df, 'green', 'red', 'ground_truth_spo2')

        # Combine the k values for each channel combination
        k_values = {
            'red/IR': k_red_ir_lasso,
            'green/IR': k_green_ir_lasso,
            'green/red': k_green_red_lasso,
        }
        
        # Calculate SpO2 per minute
        df_spo2 = spo2_per_minute_func(df, k_values)
        print(df_spo2)


# /Users/sjtok/bc_infection/wearable-data-science/data/11_19_2024/SPO2/preprocessed/parsed_spo2.csv