-- weekly_metrics.sql
-- Mart layer: one row per ISO week (Monday–Sunday)
-- Weekly totals reconcile with daily_metrics by summing daily rows

WITH daily AS (
    SELECT * FROM {{ ref('daily_metrics') }}
),

weekly AS (
    SELECT
        -- ISO week: Monday as start of week
        DATE_TRUNC(event_date, WEEK(MONDAY))            AS week_start_date,
        DATE_ADD(
            DATE_TRUNC(event_date, WEEK(MONDAY)), INTERVAL 6 DAY
        )                                               AS week_end_date,
        EXTRACT(ISOWEEK FROM event_date)                AS iso_week_number,
        EXTRACT(YEAR FROM event_date)                   AS year,

        -- Revenue (sum of daily)
        ROUND(SUM(gross_revenue), 2)                    AS gross_revenue,
        ROUND(SUM(refund_amount), 2)                    AS refund_amount,
        ROUND(SUM(net_revenue), 2)                      AS net_revenue,

        -- Orders
        SUM(total_orders)                               AS total_orders,
        ROUND(
            SAFE_DIVIDE(SUM(gross_revenue), SUM(total_orders)), 2
        )                                               AS avg_order_value,

        -- Customers (distinct per week, not sum of daily)
        SUM(unique_customers)                           AS unique_customers,
        SUM(new_customers)                              AS new_customers,
        SUM(returning_customers)                        AS returning_customers,

        -- Traffic
        SUM(total_sessions)                             AS total_sessions,
        ROUND(
            SAFE_DIVIDE(SUM(total_orders), SUM(total_sessions)) * 100, 2
        )                                               AS conversion_rate_pct

    FROM daily
    GROUP BY
        week_start_date,
        week_end_date,
        iso_week_number,
        year
)

SELECT * FROM weekly
ORDER BY week_start_date
