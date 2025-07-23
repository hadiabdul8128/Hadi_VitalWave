import numpy as np
import pandas as pd
import os
import logging
from scipy.signal import find_peaks
from datetime import timedelta
import neurokit2 as nk
from sklearn.svm import SVR
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error
import matplotlib.pyplot as plt

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def combine_dfs(ppg_directory):
    """
    Combines all CSV files containing PPG data into a single DataFrame.
    
    Arguments:
        ppg_directory (str): Directory containing CSV files for raw PPG data

    Returns:
        pd.DataFrame: Combined DataFrame with PPG data
    """
    all_data_frames = []
    
    # List of columns to keep
    columns_to_keep = ['isodate', 'acc_x', 'acc_y', 'acc_z', 'gyro_x', 'gyro_y', 'gyro_z', 'mag_x', 'mag_y', 'mag_z', 'ppg_r', 'ppg_b', 'ppg_ir', 'ppg_g']
    
    # Iterate over all files in the directory
    for filename in os.listdir(ppg_directory):
        if filename.endswith('.csv'):
            file_path = os.path.join(ppg_directory, filename)
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

def merge_ground_truth(ppg_directory, ground_truth_file):
    """
    Combines all CSV files containing PPG data and the ground truth data into a single DataFrame.
    
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

def compute_r_ratios(df):
    """
    Compute the R ratios for all combinations of channels (red, green, blue, IR).

    Arguments:
        df (pd.DataFrame): The input DataFrame containing PPG signals.
    
    Returns:
        pd.DataFrame: DataFrame containing R ratios for each combination of channels.
    """
    channels = ['red', 'green', 'blue', 'ir']
    r_ratios = {}

    # Generate all 6 possible combinations of channels
    combinations = [
        ('red', 'ir'),
        ('green', 'ir'),
        ('green', 'red'),
        ('blue', 'ir'),
        ('blue', 'green'),
        ('blue', 'red')
    ]

    for channel_1, channel_2 in combinations:
        r_ratios[f'{channel_1}_{channel_2}_r'] = calculate_r(df, channel_1, channel_2)
    
    return pd.DataFrame(r_ratios)

def svm_regression_k(df, ground_truth_column):
    """
    Train an SVM model to predict SpO2 values using R ratios as features.
    
    Arguments:
        df (pd.DataFrame): DataFrame containing R ratios and ground truth SpO2 values.
        ground_truth_column (str): The column containing the ground truth SpO2 values.

    Returns:
        model: Trained SVM model.
    """
    # Extract R ratios as features
    features = df.filter(like='_r')
    labels = df[ground_truth_column]

    X_train, X_test, y_train, y_test = train_test_split(features, labels, test_size=0.2, random_state=42)

    # Train an SVM model
    model = SVR(kernel='linear', C=1.0, epsilon=0.1)
    model.fit(X_train, y_train)

    # Predict the SpO2 values
    y_pred = model.predict(X_test)

    # Calculate Mean Absolute Error
    mae = mean_absolute_error(y_test, y_pred)

    logging.info(f"SVM Model MAE: {mae}")

    return model

def compare_spo2(df, model):
    """
    Use the trained model to predict SpO2 and compare the predictions to the ground truth.
    
    Arguments:
        df (pd.DataFrame): DataFrame containing R ratios and ground truth SpO2 values.
        model: Trained SVM model.
    
    Returns:
        pd.DataFrame: DataFrame with predicted SpO2 values compared to ground truth.
    """
    # Extract R ratios as features
    features = df.filter(like='_r')
    ground_truth_spo2 = df['ground_truth_spo2']
    
    # Predict the SpO2 values using the model
    predicted_spo2 = model.predict(features)

    comparison_df = pd.DataFrame({
        'timestamp': df['isodate'],
        'predicted_spo2': predicted_spo2,
        'ground_truth_spo2': ground_truth_spo2
    })
    
    return comparison_df

if __name__ == "__main__":
    ppg_directory_path = "/Users/sjtok/bc_infection/wearable-data-science/data/11_12_2024/BassWearable"
    ground_truth_file = "/Users/sjtok/bc_infection/wearable-data-science/data/11_12_2024/SPO2/0_Seijung Kim_11_14_24.csv"
    
    # Load the data and merge with ground truth SpO2
    df = merge_ground_truth(ppg_directory_path, ground_truth_file)
    
    if df.empty:
        logging.error("Combined DataFrame is empty for SpO2. Exiting.")
    else:
        # Compute the R ratios for all channel combinations
        r_ratios_df = compute_r_ratios(df)
        
        # Add the R ratios to the original DataFrame
        df = pd.concat([df, r_ratios_df], axis=1)
        
        # Train an SVM model to predict SpO2
        model = svm_regression_k(df, 'ground_truth_spo2')
        
        # Compare the predicted SpO2 with the ground truth
        comparison_df = compare_spo2(df, model)
        print(comparison_df)
