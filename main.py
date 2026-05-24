#!/usr/bin/env python3
"""
Darkroom ETL Pipeline
Orchestrates: extract → dbt transform → export to Google Sheets
"""

import subprocess
import sys
import os
from datetime import datetime

from pipelines.extract import run_extraction
from pipelines.export_sheets import run_export
from config.settings import START_DATE, END_DATE


def run_dbt():
    print("Running dbt transformations...")
    result = subprocess.run(
        ["dbt", "run"],
        cwd=os.path.join(os.path.dirname(__file__), "dbt_project"),
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        print("dbt run failed:")
        print(result.stdout)
        print(result.stderr)
        sys.exit(1)
    print("  ✓ dbt models built successfully")


def main():
    start_time = datetime.now()
    print("=" * 50)
    print("Darkroom ETL Pipeline")
    print(f"Started at: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)

    # Step 1 — Extract
    print("\n[1/3] Extraction")
    run_extraction(START_DATE, END_DATE)

    # Step 2 — Transform
    print("\n[2/3] Transformation (dbt)")
    run_dbt()

    # Step 3 — Export
    print("\n[3/3] Export to Google Sheets")
    run_export()

    elapsed = (datetime.now() - start_time).seconds
    print("\n" + "=" * 50)
    print(f"Pipeline complete in {elapsed}s ✓")
    print("=" * 50)


if __name__ == "__main__":
    main()
