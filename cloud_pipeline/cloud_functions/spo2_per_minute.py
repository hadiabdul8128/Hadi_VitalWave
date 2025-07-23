import numpy as np
import pandas as pd
import os
import logging
from scipy.signal import find_peaks
from datetime import timedelta 
import neurokit2 as nk 

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def combine_dfs(directory):
    """
    Combines all CSV files in a directory into a single DataFrame.
    
    Arguments:
        directory (str): directory containing CSV files

    Returns:
        pd.DataFrame: concatenated DataFrame of all CSVs sorted by isodate column
    """
    all_data_frames = []
    
    # Iterate over all files in the directory
    for filename in os.listdir(directory):
        if filename.endswith('.csv'):
            file_path = os.path.join(directory, filename)
            try:
                df = pd.read_csv(file_path)
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
        logging.error("No valid 'isodate' entries found. Cannot calculate sample rates for spo2.")
        return {}
    
    samples_per_minute = {}
    current_time = df['isodate'].min()
    
    while current_time <= df['isodate'].max(): 
        next_time = current_time + timedelta(minutes=1)
        sample_count = df[(df['isodate'] >= current_time) & (df['isodate'] < next_time)].shape[0]
        sample_rate = sample_count / 60 if sample_count > 0 else None
        samples_per_minute[current_time.floor('min')] = sample_rate
        current_time = next_time
    
    logging.info("Sample rates per minute calculated for spo2.")
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

def calculate_spo2_components(red, ir, red_peaks, red_troughs, ir_peaks, ir_troughs): 
    """
    Calculates SpO2 using AC and DC components of red and IR signals based on peaks and troughs.
    
    Arguments:
        red (array-like): PPG red signal.
        ir (array-like): PPG ir signal.
        red_peaks (array-like): Peak indices of the PPG red signal.
        red_troughs (array-like): Trough indices of the PPG red signal.
        ir_peaks (array-like): Peak indices of the PPG ir signal.
        ir_troughs (array-like): Trough indices of the PPG ir signal.

    Returns:
        float: calculated SpO2 percentage
    """
    dc_red = np.mean(red) 
    dc_ir = np.mean(ir) 
    ac_red = 0
    ac_ir = 0 

    min_len_red = min(len(red_peaks), len(red_troughs))
    min_len_ir = min(len(ir_peaks), len(ir_troughs))

    if min_len_red == 0 or min_len_ir == 0: 
        return float(0) 

    for i in range(min_len_red): 
        ac_red += (red[red_peaks[i]] - red[red_troughs[i]])
    ac_red = ac_red / min_len_red

    for i in range(min_len_ir): 
        ac_ir += (ir[ir_peaks[i]] - ir[ir_troughs[i]])
    ac_ir = ac_ir / min_len_ir

    numerator = ac_red / dc_red
    denominator = ac_ir / dc_ir 
    r = numerator / denominator 
    spo2_percent = 100 - (25 * r) 
    return float(spo2_percent)

def spo2_per_minute_func(data): 
    """
    Calculates SpO2 percentage for each minute in the dataset based on red and IR signals.
    
    Parameters:
        data (pd.DataFrame): DataFrame containing collected PPG data.
        
    Returns:
        pd.DataFrame: DataFrame with minute-level timestamps to SpO2 percentage for each minute.
    """
    # Convert 'isodate' to minute-level timestamps and group data by timestamp
    data['timestamp'] = pd.to_datetime(data['isodate']).dt.floor('min')  
    data_grouped = data.groupby('timestamp').size().reset_index(name='count')
    logging.info("Data grouped by timestamp.")

    # Calculate sample rate per minute
    sample_rates = find_sample_rate_per_minute(data)
    if not sample_rates:
        logging.error("Sample rates dictionary is empty for spo2. Exiting function.")
        return pd.DataFrame()

    spo2_per_minute = {}
    previous_mins = 0
    
    # Loop through each minute group in the data
    for _, row in data_grouped.iterrows(): 
        timestamp = row['timestamp']
        current_mins = row['count']
        
        # Retrieve the sample rate for the current minute; skip if it's missing or NaN
        sample_rate_per_minute = sample_rates.get(timestamp)
        if sample_rate_per_minute is None or np.isnan(sample_rate_per_minute):
            logging.warning(f"Sample rate for timestamp {timestamp} is NaN or missing. Skipping.")
            previous_mins += current_mins
            continue
        
        # Extract red and IR PPG signals for the current minute, dropping NaNs
        signal_red = np.array(data.ppg_r[previous_mins:previous_mins + current_mins].dropna())
        signal_ir = np.array(data.ppg_ir[previous_mins:previous_mins + current_mins].dropna())

        # If no valid data, skip this timestamp
        if len(signal_red) == 0 or len(signal_ir) == 0:
            logging.warning(f"No data for timestamp {timestamp}. Skipping.")
            previous_mins += current_mins
            continue

        # Calculate the ideal sample rates for red and IR; skip if they contain NaN values
        ideal_sample_rate_red = np.nanmedian(signal_red)
        ideal_sample_rate_ir = np.nanmedian(signal_ir)
        if np.isnan(ideal_sample_rate_red) or np.isnan(ideal_sample_rate_ir):
            logging.warning(f"NaN detected in ideal sample rates for {timestamp}. Skipping.")
            previous_mins += current_mins
            continue

        # Resample the signals if all sample rates are valid, log the resampling status
        try:
            resampled_signal_red = resampling(signal_red, sample_rate_per_minute, ideal_sample_rate_red, method="FFT")
            resampled_signal_ir = resampling(signal_ir, sample_rate_per_minute, ideal_sample_rate_ir, method="FFT")
            logging.info(f"Resampled signals for {timestamp}: Red from {sample_rate_per_minute} Hz to {ideal_sample_rate_red} Hz, IR from {sample_rate_per_minute} Hz to {ideal_sample_rate_ir} Hz.")
        except Exception as e:
            logging.error(f"Resampling failed for timestamp {timestamp}: {e}")
            previous_mins += current_mins
            continue
        
        # Detect peaks and troughs in the resampled red and IR signals
        try:
            peaks_red, _ = find_peaks(resampled_signal_red, height=0, prominence=0.002) 
            peaks_ir, _ = find_peaks(resampled_signal_ir, height=0, prominence=0.002) 
            troughs_red, _ = find_peaks(-resampled_signal_red, height=-30000, prominence=0.002) 
            troughs_ir, _ = find_peaks(-resampled_signal_ir, height=-30000, prominence=0.002) 
        except Exception as e:
            logging.error(f"Peak/trough detection failed for timestamp {timestamp}: {e}")
            previous_mins += current_mins
            continue
        
        # Move to the next minute in the data
        previous_mins += current_mins
        
        # Calculate SpO2 using red and IR peaks/troughs, adding to the results dictionary
        try:
            spo2_percent_components = calculate_spo2_components(resampled_signal_red, resampled_signal_ir, peaks_red, troughs_red, peaks_ir, troughs_ir) 
            spo2_per_minute[timestamp] = round(spo2_percent_components, 6)
        except Exception as e:
            logging.error(f"SpO2 calculation failed for timestamp {timestamp}: {e}")
            continue

    # Convert the results dictionary to a DataFrame and return it
    df = pd.DataFrame(list(spo2_per_minute.items()), columns=["timestamp", "spo2"])

    # Replace spo2 values below 89.5 with NaN
    df.loc[df["spo2"] < 89.5, "spo2"] = np.nan
    
    return df 


if __name__ == "__main__":
    directory_path = "/Users/sjtok/bc_infection/wearable-data-science/new_pipeline/test_csvs_1014"
    df = combine_dfs(directory_path)
    
    if df.empty:
        logging.error("Combined DataFrame is empty for spo2. Exiting.")
    else:
        df_spo2 = spo2_per_minute_func(df)
        print(df_spo2)
