import logging
import numpy as np
import pandas as pd
import warnings
from scipy.signal import find_peaks, butter, filtfilt
import neurokit2 as nk
from sample_freq import filter, find_sample_cnt
import imufusion  # Ensure this is installed in your environment

warnings.filterwarnings('ignore')

def fuse(df, df_sampl):
    """
    Applies sensor fusion to accelerometer, magnetometer, and gyroscope data.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The sensor data.
    df_sampl : float
        The sampling rate.
    
    Returns:
    -----------
    numpy.ndarray
        Fused acceleration magnitude vector.
    """
    # Filter the dataframe to retain necessary columns
    df = filter(df, ['acc_x', 'acc_y', 'acc_z', 'mag_x', 'mag_y', 'mag_z', 'gyro_x', 'gyro_y', 'gyro_z'])

    acc_x = df['acc_x'].values
    acc_y = df['acc_y'].values
    acc_z = df['acc_z'].values

    mag_x = df['mag_x'].values
    mag_y = df['mag_y'].values
    mag_z = df['mag_z'].values

    gyro_x = df['gyro_x'].values
    gyro_y = df['gyro_y'].values
    gyro_z = df['gyro_z'].values

    # Initialize sensor fusion algorithm
    ahrs = imufusion.Ahrs()
    fused_acc = []

    for i in range(len(acc_x)):
        accel = np.array([acc_x[i], acc_y[i], acc_z[i]])
        mag = np.array([mag_x[i], mag_y[i], mag_z[i]])
        gyro = np.array([gyro_x[i], gyro_y[i], gyro_z[i]])
        delta_time = 1 / df_sampl
        ahrs.update(gyro, accel, mag, delta_time)
        fused_acc.append(ahrs.linear_acceleration)

    return np.linalg.norm(fused_acc, axis=1)

def remove_peaks(signal, num_peaks_to_remove):
    """
    Removes noise peaks from the signal using interpolation.
    """
    modified_signal = signal.copy()
    for _ in range(num_peaks_to_remove):
        extremum_index = np.argmax(np.abs(modified_signal))
        if extremum_index > 0 and extremum_index < len(modified_signal) - 1:
            modified_signal[extremum_index] = np.mean([modified_signal[extremum_index-1], modified_signal[extremum_index+1]])
    return modified_signal

def center_and_uncenter(accel_mag, num_peaks):
    """
    Centers and removes peaks from acceleration magnitude data, then re-centers it.
    
    Parameters:
    -----------
    accel_mag : numpy.ndarray
        Acceleration magnitude vector.
    num_peaks : int
        Number of peaks to remove.
    
    Returns:
    -----------
    numpy.ndarray
        Processed acceleration magnitude vector.
    """
    original_mean = np.mean(accel_mag)
    accel_mag_centered = accel_mag - original_mean
    filtered_signal = remove_peaks(accel_mag_centered, num_peaks)
    return filtered_signal + original_mean

def resampling(signal, sampling_rate, desired_sampling_rate, method):
    """
    Resamples the signal to the desired sampling rate.
    """
    if not np.isfinite(sampling_rate) or sampling_rate <= 0:
        raise ValueError(f"Invalid sampling_rate: {sampling_rate}. Must be a positive number.")
    if not np.isfinite(desired_sampling_rate) or desired_sampling_rate <= 0:
        raise ValueError(f"Invalid desired_sampling_rate: {desired_sampling_rate}. Must be a positive number.")

    logging.info(f"Resampling signal from {sampling_rate} Hz to {desired_sampling_rate} Hz using method '{method}'.")

    try:
        resampled_signal = nk.signal_resample(signal=signal, sampling_rate=sampling_rate,
                                             desired_sampling_rate=desired_sampling_rate, method=method)
    except Exception as e:
        logging.error(f"Resampling failed: {e}")
        raise

    return resampled_signal

def low_pass_filter(signal_resampled, cutoff, fs, order):
    """
    Applies a low-pass filter to the resampled signal.
    """
    nyquist = 0.5 * fs
    normal_cutoff = cutoff / nyquist
    b, a = butter(order, normal_cutoff, btype='low', analog=False)
    return filtfilt(b, a, signal_resampled)

def steps(signal_filtered, height, prominence):
    """
    Detects steps in the filtered signal using peak detection.
    
    Parameters:
    -----------
    signal_filtered : array-like
        Filtered signal.
    height : float
        Height threshold for peak detection.
    prominence : float
        Prominence threshold for peak detection.
    
    Returns:
    -----------
    tuple: (number of steps, detected peaks indices)
    """
    peaks, properties = find_peaks(signal_filtered, height=height, prominence=prominence)
    return len(peaks), peaks

def acc_to_steps_func(df, sampl_percent=0.25, peaks_to_interpol=50, method='FFT', cutoff=5, order=5, height=0.1, prominence=0.01):
    """
    Main pipeline function for calculating step counts at the minute-level.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        The input sensor data.
    sampl_percent : float
        Percentile used to calculate sampling rate.
    peaks_to_interpol : int
        Number of peaks to remove during signal interpolation.
    method : str
        Resampling method to use ('FFT', 'numpy', etc.).
    cutoff : int
        Cutoff frequency for low-pass filter.
    order : int
        Order of the filter.
    height : float
        Height threshold for peak detection.
    prominence : float
        Prominence threshold for peak detection.

    Returns:
    -----------
    pandas.DataFrame
        DataFrame with step counts aggregated by minute, containing `timestamp` for each minute.
    """
    # Ensure 'isodate' is converted to datetime if not already
    df['isodate'] = pd.to_datetime(df['isodate'], errors='coerce')
    df.dropna(subset=['isodate'], inplace=True)
    df.sort_values('isodate', inplace=True)

    if df.empty:
        logging.error("DataFrame is empty after processing 'isodate'.")
        return pd.DataFrame()

    # Calculate sampling rates per second
    try:
        sampl_rate = find_sample_cnt(df)
        sampl_values = list(sampl_rate.values())
        if not sampl_values:
            logging.error("No sampling rate values available.")
            return pd.DataFrame()

        # Calculate sampling rate percentiles
        df_sampl = np.quantile(sampl_values, sampl_percent)
        if np.isnan(df_sampl) or df_sampl <= 0:
            logging.error(f"Invalid sampling rate calculated: {df_sampl}")
            return pd.DataFrame()
    except Exception as e:
        logging.error(f"Sampling rate calculation failed: {e}")
        return pd.DataFrame()

    # Apply sensor fusion to combine acceleration, magnetometer, and gyroscope data
    try:
        fused_accel_mag = fuse(df, df_sampl)
    except Exception as e:
        logging.error(f"Sensor fusion failed: {e}")
        return pd.DataFrame()

    # Interpolate and filter signal
    try:
        interpolated = center_and_uncenter(fused_accel_mag, peaks_to_interpol)
        desired_sampling_rate = np.median(sampl_values)
        resampled = resampling(interpolated, sampling_rate=df_sampl, 
                               desired_sampling_rate=desired_sampling_rate, method=method)
        low_pass = low_pass_filter(resampled, cutoff=cutoff, fs=desired_sampling_rate, order=order)
    except Exception as e:
        logging.error(f"Signal processing failed: {e}")
        return pd.DataFrame()

    # Step detection and aggregation
    try:
        # Create `timestamp` column to use for aggregation
        df['timestamp'] = df['isodate'].dt.floor('T')
        start_time = df['isodate'].min()
        delta_time = 1 / desired_sampling_rate

        # Detect peaks in the filtered signal
        peaks, properties = find_peaks(low_pass, height=height, prominence=prominence)

        if len(peaks) == 0:
            logging.info("No steps detected in the signal.")
            step_df = pd.DataFrame(columns=['timestamp', 'steps'])
        else:
            # Calculate the timestamp for each detected peak
            step_times = start_time + pd.to_timedelta(peaks * delta_time, unit='s')
            step_timestamps = step_times.floor('T')  # Floor to the nearest minute

            # Count steps per minute
            step_df = pd.DataFrame({'timestamp': step_timestamps})
            step_df = step_df.groupby('timestamp').size().reset_index(name='steps')

    except Exception as e:
        logging.error(f"Step detection or aggregation failed: {e}")
        return pd.DataFrame()

    return step_df