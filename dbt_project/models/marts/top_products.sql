-- top_products.sql
-- Product-level metrics aggregated across the full date range
-- Source: public dataset directly (items array requires UNNEST)

WITH purchases AS (
    SELECT
        PARSE_DATE('%Y%m%d', event_date)    AS event_date,
        item.item_id,
        item.item_name,
        CASE
    	    WHEN item.item_category IS NULL
                OR item.item_category = ''
                OR item.item_category = '(not set)'
                OR LOWER(item.item_category) = 'uncategorized items'
    	    THEN 'Uncategorized'
    	    ELSE item.item_category
	END AS item_category,
        item.price,
        item.quantity,
        COALESCE(item.item_revenue, 0)      AS item_revenue
    FROM
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
        UNNEST(items) AS item
    WHERE
        event_name = 'purchase'
        AND _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
	AND item.item_id IS NOT NULL
    	AND item.item_name != '(not set)'
    	AND item.item_revenue > 0
),

aggregated AS (
    SELECT
        item_id,
        item_name,
        item_category,
        ROUND(SUM(item_revenue), 2)         AS total_revenue,
        SUM(quantity)                        AS total_quantity_sold,
        COUNT(*)                             AS total_transactions,
        ROUND(AVG(price), 2)                AS avg_price
    FROM purchases
    GROUP BY
        item_id,
        item_name,
        item_category
)

SELECT
    *,
    RANK() OVER (ORDER BY total_revenue DESC)        AS revenue_rank,
    RANK() OVER (ORDER BY total_quantity_sold DESC)  AS quantity_rank
FROM aggregated
ORDER BY revenue_rank
