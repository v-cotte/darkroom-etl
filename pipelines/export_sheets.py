import gspread
from google.oauth2 import service_account
from google.cloud import bigquery
import pandas as pd
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config.settings import (
    PROJECT_ID, MART_DATASET, CREDENTIALS_PATH, SHEET_ID
)

SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/cloud-platform"
]

DAILY_COLUMNS = [
    "event_date", "gross_revenue", "refund_amount", "net_revenue",
    "total_orders", "avg_order_value", "unique_customers",
    "new_customers", "returning_customers", "total_sessions",
    "conversion_rate_pct"
]

WEEKLY_COLUMNS = [
    "week_start_date", "week_end_date", "iso_week_number", "year",
    "gross_revenue", "refund_amount", "net_revenue",
    "total_orders", "avg_order_value", "unique_customers",
    "new_customers", "returning_customers", "total_sessions",
    "conversion_rate_pct"
]

PRODUCT_COLUMNS = [
    "item_id", "item_name", "item_category", "total_revenue",
    "total_quantity_sold", "total_transactions", "avg_price",
    "revenue_rank", "quantity_rank"
]

def get_credentials():
    return service_account.Credentials.from_service_account_file(
        CREDENTIALS_PATH,
        scopes=SCOPES
    )


def fetch_table_as_df(table_name: str) -> pd.DataFrame:
    """Fetch a BigQuery mart table into a pandas DataFrame."""
    credentials = get_credentials()
    client = bigquery.Client(project=PROJECT_ID, credentials=credentials)
    query = f"SELECT * FROM `{PROJECT_ID}.{MART_DATASET}.{table_name}` ORDER BY 1"
    df = client.query(query).to_dataframe()
    # Convert date columns to string for Sheets compatibility
    for col in df.select_dtypes(include=["dbdate", "object"]):
        df[col] = df[col].astype(str)
    for col in df.select_dtypes(include=["datetime64[ns]", "datetime64[ns, UTC]"]):
        df[col] = df[col].dt.strftime("%Y-%m-%d")
    return df


def update_sheet_tab(sheet, tab_name: str, df: pd.DataFrame):
    """Overwrite a sheet tab with fresh data, preserving headers."""
    n_rows = len(df) + 10
    n_cols = len(df.columns) + 2

    try:
        worksheet = sheet.worksheet(tab_name)
        print(f"  Tab '{tab_name}' found — clearing...")
        worksheet.clear()
        worksheet.resize(rows=n_rows, cols=n_cols)
    except gspread.exceptions.WorksheetNotFound:
        print(f"  Tab '{tab_name}' not found — creating...")
        worksheet = sheet.add_worksheet(title=tab_name, rows=n_rows, cols=n_cols)

    # Convert nullable dtypes to native Python types before serialization
    df = df.astype(object).where(df.notna(), other=None)

    # Write headers + data
    headers = df.columns.tolist()
    rows = [
        [("" if v is None else v) for v in row]
        for row in df.values.tolist()
    ]
    all_data = [headers] + rows

    worksheet.update(all_data, value_input_option="USER_ENTERED")
    print(f"  ✓ '{tab_name}' updated — {len(rows)} rows written")


def run_export():
    print("Starting Google Sheets export...")

    credentials = get_credentials()
    gc = gspread.authorize(credentials)

    print(f"  Opening sheet: {SHEET_ID}")
    sheet = gc.open_by_key(SHEET_ID)

    # Daily metrics
    print("Fetching daily_metrics from BigQuery...")
    daily_df = fetch_table_as_df("daily_metrics")
    update_sheet_tab(sheet, "Daily Metrics", daily_df)

    # Weekly metrics
    print("Fetching weekly_metrics from BigQuery...")
    weekly_df = fetch_table_as_df("weekly_metrics")
    update_sheet_tab(sheet, "Weekly Metrics", weekly_df)

    # Top products
    print("Fetching top_products from BigQuery...")
    products_df = fetch_table_as_df("top_products")
    update_sheet_tab(sheet, "Top Products", products_df)

    print("\nExport complete ✓")
    print(f"Sheet URL: https://docs.google.com/spreadsheets/d/{SHEET_ID}")


if __name__ == "__main__":
    run_export()
