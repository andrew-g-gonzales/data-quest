import pandas as pd
import os

def main(event, context):

    s3_bls_gov_current_file = os.environ['S3_BLS_CSV_FILE']
    s3_datausa_file = os.environ['S3_DATAUSA_FILE']
    print(s3_bls_gov_current_file)
    print(s3_datausa_file)

    #Fetching pr.data.0.Current.csv file from S3 into Data Frame
    csv_df = pd.read_csv(s3_bls_gov_current_file, delimiter=r"\s+")
    csv_df = csv_df[["series_id", "year", "period", "value"]]

    #Fetching datausa.json file from S3 into Data Frame
    json_df = pd.read_json(s3_datausa_file)
    json_df.columns = json_df.columns.str.lower()

    #Filtering for annual US population across the years [2013, 2018] inclusive
    df_filtered_json = json_df.query('2013 <= year <= 2018')

    print(f"Standard Deviation of population: {round(df_filtered_json['population'].std(),3)}")
    print(f"Mean of population: {round(df_filtered_json['population'].mean())}")

    #Finding the year with the max/largest sum of "value" for all quarters in that 
    # year for every series_id.
    df_best_yr = csv_df.groupby(["series_id", "year"], as_index=False)["value"].sum()
    df_best_yr = df_best_yr.loc[
        df_best_yr.groupby(["series_id"])["value"].idxmax()
        ].reset_index(drop=True)

    #Generating a report using both dataframes that will provide the value for
    #series_id = PRS30006032 and period = Q01 and the population for that given year
    df_filtered = csv_df.query('series_id == "PRS30006032" and period == "Q01"')
    df_merged = pd.merge(
        df_filtered, json_df, on=['year'], how='left'
        )[['series_id', 'year', 'period', 'value', 'population']]

    print(df_merged.to_string())
    