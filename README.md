# Darkroom ETL Pipeline

End-to-end data engineering pipeline built as a take-home assessment.
Extracts GA4 e-commerce data from BigQuery, transforms it with dbt,
and exports reporting metrics to Google Sheets.

---

## Architecture

BigQuery Public Dataset (GA4)
↓
Extract (Python) → ecommerce_raw.raw_events
↓
Transform (dbt) → ecommerce_mart
├── stg_events (view)
├── daily_metrics (table)
├── weekly_metrics (table)
└── top_products (table)
↓
Export (Python + gspread) → Google Sheets

---

## Stack

| Layer | Technology |
|---|---|
| Extraction | Python, `google-cloud-bigquery` |
| Storage | BigQuery (GCP) |
| Transformation | dbt-bigquery |
| Export | Python, `gspread` |
| Orchestration | `main.py` (production: Cloud Run + Cloud Scheduler) |

---

## Project Structure

darkroom-etl/
├── config/
│   └── settings.py          # Environment config
├── pipelines/
│   ├── extract.py           # BQ public → ecommerce_raw
│   └── export_sheets.py     # ecommerce_mart → Google Sheets
├── dbt_project/
│   └── models/
│       ├── staging/
│       │   └── stg_events.sql
│       └── marts/
│           ├── daily_metrics.sql
│           ├── weekly_metrics.sql
│           └── top_products.sql
├── main.py                  # Pipeline orchestrator
├── production_design.md     # GCP production architecture
└── requirements.txt

---

## Metrics Produced

**Daily & Weekly:**
- Gross Revenue, Refund Amount, Net Revenue
- Total Orders, Average Order Value
- Unique Customers, New vs Returning Customers
- Sessions, Conversion Rate

**Products:**
- Top Products by Revenue (ranked)
- Top Products by Quantity Sold (ranked)

---

## Setup

### Prerequisites
- GCP project with BigQuery enabled
- Service account with BigQuery Admin + Sheets Editor roles
- Python 3.12+

### Installation

```bash
git clone https://github.com/v-cotte/darkroom-etl.git
cd darkroom-etl
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Configuration

Create a `.env` file:

GCP_PROJECT_ID=darkroom-etl-assignment
GOOGLE_APPLICATION_CREDENTIALS=credentials.json
GOOGLE_SHEET_ID=1yaMog_4KcyM9XqvCObuIgPTgtABoBNw8GBCe23aTKlo

Place your service account `credentials.json` in the project root.

Initialize dbt:

```bash
cd dbt_project
dbt debug
```

### Run

```bash
# Full pipeline
python main.py

# Individual stages
python pipelines/extract.py
cd dbt_project && dbt run
python pipelines/export_sheets.py
```

---

## Google Sheets Output

[View Live Report](YOUR_SHEET_URL_HERE)

Contains three tabs:
- **Daily Metrics** — 92 rows (Nov 2020 – Jan 2021)
- **Weekly Metrics** — 15 ISO weeks
- **Top Products** — ranked by revenue and quantity

---

## Production Design

See [`production_design.md`](production_design.md) for the full GCP
production architecture including scheduling, failure handling,
retry strategy, and monitoring.

---

## Data Source

`bigquery-public-data.ga4_obfuscated_sample_ecommerce`
Nov 2020 – Jan 2021 · Google Merchandise Store · GA4 format
