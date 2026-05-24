import os
from dotenv import load_dotenv

load_dotenv()

PROJECT_ID = os.getenv("GCP_PROJECT_ID")
RAW_DATASET = "ecommerce_raw"
MART_DATASET = "ecommerce_mart"
CREDENTIALS_PATH = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "credentials.json")
SHEET_ID = os.getenv("GOOGLE_SHEET_ID")

SOURCE_PROJECT = "bigquery-public-data"
SOURCE_DATASET = "ga4_obfuscated_sample_ecommerce"

START_DATE = "20201101"
END_DATE = "20210131"
