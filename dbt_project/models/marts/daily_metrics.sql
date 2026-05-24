-- daily_metrics.sql
-- Mart layer: one row per day with all required business metrics

WITH events AS (
    SELECT * FROM {{ ref('stg_events') }}
),

-- Revenue metrics (purchase events only)
revenue AS (
    SELECT
        event_date,
        SUM(purchase_revenue)                           AS gross_revenue,
        SUM(refund_value)                               AS refund_amount,
        SUM(purchase_revenue) - SUM(refund_value)       AS net_revenue,
        COUNT(DISTINCT order_key)                       AS total_orders,
        SAFE_DIVIDE(
            SUM(purchase_revenue),
            COUNT(DISTINCT order_key)
        )                                               AS avg_order_value
    FROM events
    WHERE event_name = 'purchase'
    GROUP BY event_date
),

-- Customer metrics
customers AS (
    SELECT
        event_date,
        COUNT(DISTINCT user_pseudo_id)                  AS unique_customers
    FROM events
    WHERE event_name = 'purchase'
    GROUP BY event_date
),

-- New vs returning: a user is "new" on the first date they ever purchased
first_purchase AS (
    SELECT
        user_pseudo_id,
        MIN(event_date)                                 AS first_purchase_date
    FROM events
    WHERE event_name = 'purchase'
    GROUP BY user_pseudo_id
),

new_vs_returning AS (
    SELECT
        e.event_date,
        COUNT(DISTINCT CASE
            WHEN e.event_date = fp.first_purchase_date THEN e.user_pseudo_id
        END)                                            AS new_customers,
        COUNT(DISTINCT CASE
            WHEN e.event_date > fp.first_purchase_date THEN e.user_pseudo_id
        END)                                            AS returning_customers
    FROM events e
    JOIN first_purchase fp ON e.user_pseudo_id = fp.user_pseudo_id
    WHERE e.event_name = 'purchase'
    GROUP BY e.event_date
),

-- Session metrics
sessions AS (
    SELECT
        event_date,
        COUNT(DISTINCT CONCAT(
            user_pseudo_id, '_', CAST(session_id AS STRING)
        ))                                              AS total_sessions
    FROM events
    WHERE event_name = 'session_start'
    GROUP BY event_date
),

-- Conversion rate = orders / sessions
final AS (
    SELECT
        r.event_date,

        -- Revenue
        ROUND(r.gross_revenue, 2)                       AS gross_revenue,
        ROUND(r.refund_amount, 2)                       AS refund_amount,
        ROUND(r.net_revenue, 2)                         AS net_revenue,

        -- Orders
        r.total_orders,
        ROUND(r.avg_order_value, 2)                     AS avg_order_value,

        -- Customers
        c.unique_customers,
        nvr.new_customers,
        nvr.returning_customers,

        -- Traffic
        s.total_sessions,
        ROUND(
            SAFE_DIVIDE(r.total_orders, s.total_sessions) * 100, 2
        )                                               AS conversion_rate_pct

    FROM revenue r
    LEFT JOIN customers c          ON r.event_date = c.event_date
    LEFT JOIN new_vs_returning nvr ON r.event_date = nvr.event_date
    LEFT JOIN sessions s           ON r.event_date = s.event_date
)

SELECT * FROM final
ORDER BY event_date
