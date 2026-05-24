-- weekly_metrics.sql
-- Mart layer: one row per ISO week (Monday–Sunday)
-- Built from stg_events directly to correctly deduplicate customers per week

WITH events AS (
    SELECT * FROM {{ ref('stg_events') }}
),

first_purchase AS (
    SELECT
        user_pseudo_id,
        MIN(event_date) AS first_purchase_date
    FROM events
    WHERE event_name = 'purchase'
    GROUP BY user_pseudo_id
),

weeks AS (
    SELECT
        DATE_TRUNC(event_date, WEEK(MONDAY))            AS week_start_date,
        DATE_ADD(
            DATE_TRUNC(event_date, WEEK(MONDAY)), INTERVAL 6 DAY
        )                                               AS week_end_date,
        EXTRACT(ISOWEEK FROM event_date)                AS iso_week_number,
        EXTRACT(YEAR FROM event_date)                   AS year,

        -- Revenue
        ROUND(SUM(CASE WHEN event_name = 'purchase' THEN purchase_revenue ELSE 0 END), 2)
                                                        AS gross_revenue,
        ROUND(SUM(CASE WHEN event_name = 'purchase' THEN refund_value ELSE 0 END), 2)
                                                        AS refund_amount,
        ROUND(
            SUM(CASE WHEN event_name = 'purchase' THEN purchase_revenue ELSE 0 END)
          - SUM(CASE WHEN event_name = 'purchase' THEN refund_value ELSE 0 END), 2
        )                                               AS net_revenue,

        -- Orders
        COUNT(DISTINCT CASE WHEN event_name = 'purchase' THEN order_key END)
                                                        AS total_orders,

        -- Sessions
        COUNT(DISTINCT CASE
            WHEN event_name = 'session_start'
            THEN CONCAT(user_pseudo_id, '_', CAST(session_id AS STRING))
        END)                                            AS total_sessions

    FROM events
    GROUP BY
        week_start_date,
        week_end_date,
        iso_week_number,
        year
),

customer_metrics AS (
    SELECT
        DATE_TRUNC(e.event_date, WEEK(MONDAY))          AS week_start_date,
        COUNT(DISTINCT e.user_pseudo_id)                AS unique_customers,
        COUNT(DISTINCT CASE
            WHEN DATE_TRUNC(e.event_date, WEEK(MONDAY))
               = DATE_TRUNC(fp.first_purchase_date, WEEK(MONDAY))
            THEN e.user_pseudo_id
        END)                                            AS new_customers,
        COUNT(DISTINCT CASE
            WHEN DATE_TRUNC(e.event_date, WEEK(MONDAY))
               > DATE_TRUNC(fp.first_purchase_date, WEEK(MONDAY))
            THEN e.user_pseudo_id
        END)                                            AS returning_customers
    FROM events e
    JOIN first_purchase fp ON e.user_pseudo_id = fp.user_pseudo_id
    WHERE e.event_name = 'purchase'
    GROUP BY week_start_date
)

SELECT
    w.week_start_date,
    w.week_end_date,
    w.iso_week_number,
    w.year,
    w.gross_revenue,
    w.refund_amount,
    w.net_revenue,
    w.total_orders,
    ROUND(SAFE_DIVIDE(w.gross_revenue, w.total_orders), 2) AS avg_order_value,
    c.unique_customers,
    c.new_customers,
    c.returning_customers,
    w.total_sessions,
    ROUND(SAFE_DIVIDE(w.total_orders, w.total_sessions) * 100, 2) AS conversion_rate_pct
FROM weeks w
LEFT JOIN customer_metrics c ON w.week_start_date = c.week_start_date
ORDER BY w.week_start_date
