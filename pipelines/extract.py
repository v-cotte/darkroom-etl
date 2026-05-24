from google.cloud import bigquery
from google.oauth2 import service_account
from datetime import datetime, timedelta
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import (
    PROJECT_ID, RAW_DATASET, SOURCE_PROJECT,
    SOURCE_DATASET, CREDENTIALS_PATH, START_DATE, END_DATE
)


def get_bq_client():
    credentials = service_account.Credentials.from_service_account_file(
        CREDENTIALS_PATH,
        scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    return bigquery.Client(project=PROJECT_ID, credentials=credentials)


def get_date_range(start: str, end: str):
    """Generate list of dates in YYYYMMDD format between start and end inclusive."""
    start_dt = datetime.strptime(start, "%Y%m%d")
    end_dt = datetime.strptime(end, "%Y%m%d")
    delta = (end_dt - start_dt).days + 1
    return [
        (start_dt + timedelta(days=i)).strftime("%Y%m%d")
        for i in range(delta)
    ]


def date_already_ingested(client: bigquery.Client, event_date: str) -> bool:
    """Check if a date has already been loaded into the raw table."""
    query = f"""
        SELECT COUNT(*) as cnt
        FROM `{PROJECT_ID}.{RAW_DATASET}.raw_events`
        WHERE event_date = '{event_date}'
    """
    try:
        result = list(client.query(query).result())
        return result[0].cnt > 0
    except Exception:
        # Table doesn't exist yet
        return False


def ingest_date(client: bigquery.Client, event_date: str):
    """Extract one day from the public dataset and load into raw_events."""
    print(f"  Ingesting {event_date}...")

    query = f"""
        SELECT
            event_date,
            event_timestamp,
            event_name,
            user_pseudo_id,
            
            -- Session info
            (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
            (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged') AS session_engaged,
            
            -- Traffic source
            traffic_source.source AS traffic_source,
            traffic_source.medium AS traffic_medium,
            
            -- Ecommerce fields (populated on purchase events)
            ecommerce.transaction_id,
            ecommerce.purchase_revenue,
            ecommerce.refund_value,
            ecommerce.tax_value,
            ecommerce.shipping_value,
            
            -- Device info
            device.category AS device_category,
            device.operating_system,
            
            -- Geo
            geo.country,
            
            -- Ingestion metadata
            CURRENT_TIMESTAMP() AS ingested_at

        FROM `{SOURCE_PROJECT}.{SOURCE_DATASET}.events_{event_date}`
    """

    destination = f"{PROJECT_ID}.{RAW_DATASET}.raw_events"

    job_config = bigquery.QueryJobConfig(
        destination=destination,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        time_partitioning=bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field="ingested_at"
        )
    )

    job = client.query(query, job_config=job_config)
    job.result()
    print(f"  ✓ {event_date} loaded successfully")


def run_extraction(start_date: str = START_DATE, end_date: str = END_DATE):
    print("Starting extraction pipeline...")
    print(f"Date range: {start_date} → {end_date}")

    client = get_bq_client()
    dates = get_date_range(start_date, end_date)
    
    skipped = 0
    ingested = 0

    for date in dates:
        if date_already_ingested(client, date):
            print(f"  Skipping {date} — already ingested")
            skipped += 1
        else:
            ingest_date(client, date)
            ingested += 1

    print(f"\nExtraction complete — {ingested} dates ingested, {skipped} skipped")


if __name__ == "__main__":
    run_extraction()
