# Production Pipeline Design

## Overview

This document describes how the Darkroom ETL pipeline would be deployed and
operated in a production GCP environment, running automatically every day.

---

## Architecture Diagram

    Cloud Scheduler (daily cron)
            ↓
    Cloud Run Job
        ├── 1. Extract (BigQuery public → ecommerce_raw)
        ├── 2. Transform (dbt run → ecommerce_mart)
        └── 3. Export (BigQuery → Google Sheets)
            ↓
    Cloud Logging + Error Reporting
            ↓
    Alerting (Email / Slack via Cloud Monitoring)

---

## GCP Services

| Service | Purpose |
|---|---|
| **Cloud Run Jobs** | Execute the pipeline container on demand or on schedule |
| **Cloud Scheduler** | Trigger the Cloud Run Job daily at a fixed time |
| **BigQuery** | Raw data storage, transformation, and mart layer |
| **Secret Manager** | Store credentials and environment variables securely |
| **Cloud Logging** | Centralized logging for all pipeline runs |
| **Cloud Monitoring** | Alerting on failures, latency, and data quality |
| **Artifact Registry** | Store the Docker image for the pipeline |
| **Google Sheets API** | Final reporting output for business users |

---

## Scheduling Approach

Cloud Scheduler triggers the Cloud Run Job once per day at **06:00 UTC**
using a cron expression: `0 6 * * *`

This gives business users fresh data by the time they start their day
across EST and European time zones.

The pipeline is designed to be **idempotent** - running it multiple times
on the same day produces the same result. The extraction layer checks
whether a date has already been ingested before loading it, and dbt
overwrites mart tables on each run.

---

## Incremental Loading Strategy

The extraction layer uses date-based incremental loading:

1. On each run, the pipeline checks which dates already exist in
   `ecommerce_raw.raw_events`
2. Only missing dates are extracted from the source
3. This avoids full reloads and keeps costs low

In production with a live GA4 property, the pipeline would extract
**yesterday's date** on each daily run:

```python
from datetime import date, timedelta
target_date = (date.today() - timedelta(days=1)).strftime("%Y%m%d")
run_extraction(target_date, target_date)
```

GA4 data can arrive with a 24–48 hour delay, so extracting yesterday
ensures complete data before transformation.

---

## Google Sheets Update Strategy

The Sheets export uses an **overwrite** strategy:

- On each run, each tab is cleared and rewritten from scratch
- This guarantees no duplicate rows and no stale data
- Date deduplication is handled upstream in BigQuery, not in Sheets

An alternative **append** strategy was considered but rejected because:
- It requires explicit deduplication logic in the export layer
- A failed partial run could leave the Sheet in an inconsistent state
- Overwrite is simpler, safer, and easier to audit

---

## Failure Handling & Retry Strategy

### Cloud Run Job retries
Cloud Run Jobs support automatic retries. Configure:
- **Max retries:** 3
- **Retry delay:** exponential backoff starting at 10s

### Pipeline-level failure handling
Each stage (extract, transform, export) fails loudly with a non-zero
exit code. If any stage fails, subsequent stages do not run. This
prevents partial or inconsistent data from reaching the Sheets output.

### dbt failures
dbt run exits with a non-zero code on model failure, which propagates
to the Cloud Run Job and triggers a retry.

### Idempotency as a safety net
Because the pipeline is idempotent, a retry after failure is safe -
it will skip already-ingested dates and reprocess only what's missing.

---

## Logging & Monitoring

### Logging
All pipeline stages emit structured logs to stdout, which Cloud Run
automatically forwards to **Cloud Logging**. Log entries include:

- Pipeline start/end timestamps
- Dates ingested vs skipped
- Row counts written to each Sheets tab
- Any exceptions with full stack traces

### Monitoring & Alerting
Cloud Monitoring is configured with:

- **Uptime check:** alert if the Cloud Run Job does not complete
  successfully by 08:00 UTC
- **Error rate alert:** alert on any ERROR-level log entry
- **Notification channel:** email + Slack webhook

### Data quality checks
dbt tests run after each model build:
- `not_null` on key metric columns
- `unique` on `event_date` in `daily_metrics`
- Row count assertions to catch empty loads

---

## Cost Considerations

- BigQuery charges per byte scanned - partition pruning on `ingested_at`
  keeps daily incremental queries cheap
- Cloud Run Jobs bill only for execution time - a daily lightweight
  pipeline costs cents per month
- The public GA4 dataset is free to query up to 1TB/month

---

## Security

- Service account credentials stored in **Secret Manager**, not in code
  or environment variables
- Service account follows least-privilege: BigQuery Data Editor +
  Job User + Sheets Editor only
- No credentials committed to source control (enforced via `.gitignore`)
