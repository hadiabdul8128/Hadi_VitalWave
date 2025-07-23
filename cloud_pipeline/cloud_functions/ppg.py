from acc_to_steps import *
# from cloud_pipeline import * # removed this import as it seems it's not called
from sample_freq import *
import logging

def hr_and_hrv(df, channel):
    """
    df: combined df 
    channel: string (for appropriate channel) 

    outputs heart rate and heart rate variability in tuple form (hr, hrv) for specified channel
    """
    # ppg = df[ppg_col] 
    ppg_col = f'ppg_{channel}'
    ppg = df[ppg_col].dropna()  # Filter out NaN values

    if ppg.empty:
        logging.warning(f"No valid data in {ppg_col} for HR/HRV calculation. Skipping.")
        return None, None

    real_sampl = np.quantile(list(find_sample_cnt(df).values()), 0.15)
    resampl = np.median(list(find_sample_cnt(df).values()))
    
    data = nk.ppg_clean(ppg, sampling_rate=real_sampl, method='elgendi')
    signals, info = nk.ppg_process(data, sampling_rate=real_sampl, method='elgendi')

    logging.info(f"Original sampling rate for {channel} channel: {real_sampl} Hz, Resampled rate: {resampl} Hz for hr/hrv")

    hrv = nk.hrv(signals, sampling_rate=resampl)['HRV_RMSSD'].iloc[0]
    hr = np.median((signals['PPG_Rate']))
    
    if np.isnan(hr) or np.isnan(hrv):
            logging.warning(f"HR or HRV calculation returned NaN for {channel} channel.")
            return None, None
    
    return hr, hrv

""" def backup_func(data):
    
    #in progress rn
    
    if not data['ppg_1'].isnull().all():
        ppg_peaks, _ = find_peaks(data['ppg_1'], distance=20)
        data['heart_beats'] = 0
        data.loc[ppg_peaks, 'heart_beats'] = 1 """

def calculate_ppg_per_minute(data):
    """
    Takes in dataframe and calculates steps by minute. Helper function for calculate_metrics_per_min

    Parameters
    -----------
    data: pandas df
        filtered dataframe with non-na values filtered out.

    Returns
    -----------
    metrics: pandas df
        contains hr and hrv per minute
    """
    data['datetime'] = pd.to_datetime(data['isodate'])
   #data.sort_values('datetime', inplace=True)
    data.sort_values('datetime', inplace=True)

    data['timestamp'] = data['datetime'].dt.floor('min')
    grouped = data.groupby('timestamp')
    
    ppg_per_minute = []
    for minute, group in grouped:
        if len(group) <1500:  # Skip empty groups, need to adjust this metric
            logging.warning(f"Insufficient data points for timestamp {minute}. Skipping calculation for hr/hrv.")
            ppg_per_minute.append({'timestamp': minute, 'hr': None, 'hrv': None})
            continue
        #print(len(group['isodate']))
        # Please adjust metrics as necessary after testing/training. 
        hr_ir, hrv_ir = hr_and_hrv(group, 'ir') 
        hr_r, hrv_r = hr_and_hrv(group, 'r') #should be chnaged to r (changed from 1)
        hr_g, hrv_g = hr_and_hrv(group, 'g')  #COMMENT THESE OUT AFTER NEW DATA
        hr_b, hrv_b = hr_and_hrv(group, 'b')  #COMMENT THESE OUT AFTER NEW DATA
        hr = np.mean(hr_ir + hr_r + hr_b + hr_g) # + hr_b + hr_g
        hrv = np.mean(hrv_ir + hrv_r + hrv_b + hrv_g) # + hrv_b + hrv_g

        ppg_per_minute.append({'timestamp': minute, 'hr': hr, 'hrv': hrv})
    
    return pd.DataFrame(ppg_per_minute)


# testing in file
if __name__ == "__main__":
    ppg_df = combine_dfs("/Users/sjtok/bc_infection/wearable-data-science/new_pipeline/test_csvs_1014") # only really works on long files
    print(ppg_df)
    print(calculate_ppg_per_minute(ppg_df))