from ppg import calculate_ppg_per_minute
from spo2_per_minute import spo2_per_minute_func
from acc_to_steps import acc_to_steps_func
import pandas as pd
import numpy as np
import logging
from datetime import datetime

def calculate_metrics_per_minute(data):
    """
    Aggregates raw sensor data into minute-level metrics, including waypoints, battery, air_temp,
    thermistor, press, humid, steps, hr, hrv, and SpO2.

    Parameters:
    -----------
    data : pandas.DataFrame
        DataFrame containing raw sensor data.

    Returns:
    -----------
    pandas.DataFrame
        Aggregated minute-level metrics, including steps, hr, hrv, and SpO2.
    """
    if data.empty:
        logging.warning("Input data is empty. Returning an empty DataFrame.")
        return pd.DataFrame()

    # Convert 'isodate' to datetime and create a 'timestamp' column at the minute level
    data['datetime'] = pd.to_datetime(data['isodate'], errors='coerce')
    data.dropna(subset=['datetime'], inplace=True)
    data.sort_values('datetime', inplace=True)
    data['timestamp'] = data['datetime'].dt.floor('min')

    # Aggregate core metrics by minute, with "press" hardcoded to 99700.0
    try:
        metrics = data.groupby('timestamp').agg(
            waypoints=('waypoints', lambda x: round(x.median(), 3)),
            battery=('battery', lambda x: round(x.median(), 3)),
            air_temp=('air_temp', lambda x: round(x.median(), 3)),
            thermistor=('thermistor', lambda x: round(x.median(), 3)),
            # press=('press', lambda x: round(x.median(), 3)),  # Commented out to hardcode value
            humid=('humid', lambda x: round(x.median(), 3))
        ).reset_index()

        # Hardcode "press" to 99700.0 for each row
        metrics['press'] = 99700.0
    except Exception as e:
        logging.error(f"Failed to aggregate core metrics: {e}")
        return pd.DataFrame()

    # Calculate additional metrics and add them directly to the metrics DataFrame
    try:
        # Steps
        # step_df = acc_to_steps_func(data)
        step_df = acc_to_steps_func(data, sampl_percent=0.25, peaks_to_interpol=50)

        metrics = metrics.merge(step_df, on='timestamp', how='left')

        # Heart Rate and HRV (from IR and R channels)
        hr_df = calculate_ppg_per_minute(data)  # Call calculate_ppg_per_minute to get hr and hrv per minute
        hr_df['hr'] = hr_df['hr'].round(3)
        hr_df['hrv'] = hr_df['hrv'].round(3)
        metrics = metrics.merge(hr_df, on='timestamp', how='left')

        # SpO2
        try:
            spo2_df = spo2_per_minute_func(data)
            spo2_df['spo2'] = spo2_df['spo2'].round(3)
            metrics = metrics.merge(spo2_df, on='timestamp', how='left')
        except Exception as e:
            logging.error(f"Failed to calculate SpO2: {e}")

    except Exception as e:
        logging.error(f"Error adding additional metrics to DataFrame: {e}")
        return pd.DataFrame()

    return metrics

# if __name__ == "__main__":
    # data = 
    # df_metrics = calculate_metrics_per_minute(data)
    # print(df_metrics)
