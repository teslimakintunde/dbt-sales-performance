{{ config(
    materialized='table',
    partition_by={'field': 'order_date', 'data_type': 'date'},
    cluster_by=['region', 'product_category']
) }}

-- Grain: one sales line.


select
    -- keys
    line_item_id,
    order_id,
    customer_id,
    product_id,

    -- product
    product_name,
    product_category,
    subcategory,
    brand,
    supplier_code,

    -- customer
    loyalty_tier,
    customer_segment,
    acquisition_channel,

    -- order context
    region,
    sales_channel,
    payment_method,
    campaign_id,
    warehouse_id,
    order_priority,
    delivery_status,

    -- unit economics
    quantity,
    unit_price,
    unit_cost,
    standard_unit_cost,
    discount_applied,
    discount_band,
    discount_band_sort,

    -- line amounts before cancellation gating
    gross_revenue,
    discount_amount,
    sales_after_discount,
    cost_of_goods_sold,
    shipping_fee_amount,

    -- recognized amounts (cancelled = 0)
    recognized_revenue,
    recognized_discount_amount,
    recognized_cogs,
    recognized_cogs_at_standard,
    recognized_shipping_fee,
    estimated_contribution_profit,
    estimated_contribution_profit as gross_profit,   -- same value, clearer name for Looker

    -- flags
    is_cancelled,
    return_requested,
    is_free_shipping,
    has_missing_cost,
    has_missing_standard_cost,

    -- calendar attributes for Looker Studio
    order_date,
    date_trunc(order_date, month)                          as order_month,
    date_trunc(order_date, quarter)                        as order_quarter,
    extract(year from order_date)                          as order_year,
    extract(month from order_date)                         as month_number,
    format_date('%b', order_date)                          as month_name,
    format_date('%B', order_date)                          as month_name_full,
    format_date('%Y-%m', order_date)                       as month_year_label,
    extract(year from order_date) * 100
      + extract(month from order_date)                     as year_month_sort

from {{ ref('int_sales_enriched') }}