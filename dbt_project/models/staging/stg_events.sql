-- stg_events.sql
-- Staging layer: clean and flatten raw_events
-- One row per event, with all relevant fields typed and named consistently

WITH source AS (
    SELECT
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        session_id,
        session_engaged,
        traffic_source,
        traffic_medium,
        transaction_id,
        purchase_revenue,
        refund_value,
        tax_value,
        shipping_value,
        device_category,
        country,
        ingested_at
    FROM `{{ env_var('DBT_PROJECT_ID') }}.ecommerce_raw.raw_events`
),

cleaned AS (
    SELECT
        -- Date as proper DATE type
        PARSE_DATE('%Y%m%d', event_date)            AS event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        session_id,

        -- Normalize session_engaged to boolean
        CASE
            WHEN session_engaged = '1' THEN TRUE
            ELSE FALSE
        END                                          AS session_engaged,

        traffic_source,
        traffic_medium,

        -- transaction_id: nullify '(not set)' values
        NULLIF(transaction_id, '(not set)')          AS transaction_id,

        -- Revenue fields: null → 0
        COALESCE(purchase_revenue, 0)                AS purchase_revenue,
        COALESCE(refund_value, 0)                    AS refund_value,
        COALESCE(tax_value, 0)                       AS tax_value,
        COALESCE(shipping_value, 0)                  AS shipping_value,

        device_category,
        country,
        ingested_at,

        -- Surrogate order key (since transaction_id is unreliable)
        CONCAT(user_pseudo_id, '_', CAST(event_timestamp AS STRING)) AS order_key

    FROM source
)

SELECT * FROM cleaned
