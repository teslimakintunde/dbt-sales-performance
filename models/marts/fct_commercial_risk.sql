{{ config(
    materialized='table',
    partition_by={'field': 'order_date', 'data_type': 'date'},
    cluster_by=['region', 'product_category']
) }}

-- Grain: one sales line.
-- Change the threshold without editing SQL:  dbt build --vars '{high_discount_threshold: 0.12}'
{% set high_discount = var('high_discount_threshold', 0.10) %}

with base as (
    select
        *,
        -- RAW flags: did the event happen on this line at all, regardless of cancellation?
        coalesce(return_requested, false)                        as raw_is_returned,
        coalesce(is_late_delivery, false)                        as raw_is_late,
        (is_late_delivery is not null)                           as raw_is_delivery_measured,
        (coalesce(discount_applied, 0) >= {{ high_discount }})   as raw_is_high_discount
    from {{ ref('int_sales_enriched') }}
),

flags as (
    select
        *,
        -- GATED flags: true only on non-cancelled lines (used for revenue, exposure and rates)
        (raw_is_returned and not is_cancelled)                   as is_returned,
        (raw_is_late and not is_cancelled)                       as is_late,
        (raw_is_delivery_measured and not is_cancelled)          as is_delivery_measured,
        (raw_is_high_discount and not is_cancelled)              as is_high_discount,

        -- cancelled lines that ALSO had another risk before/while being cancelled
        (is_cancelled and (raw_is_returned or raw_is_late or raw_is_high_discount))
                                                                 as cancelled_with_other_flags
    from base
)

select
    line_item_id,
    order_id,
    customer_id,
    product_id,
    product_name,
    product_category,
    subcategory,
    brand,
    supplier_code,

    region,
    sales_channel,
    payment_method,
    campaign_id,
    warehouse_id,
    order_priority,

    delivery_status,
    estimated_delivery,
    actual_delivery,
    delivery_variance_days,
    discount_applied,
    discount_band,
    discount_band_sort,

    -- gated flags (financial metrics)
    is_cancelled,
    is_returned,
    is_late,
    is_delivery_measured,
    is_high_discount,

   
    raw_is_returned,
    raw_is_late,
    raw_is_high_discount,
    cancelled_with_other_flags,

   
   
    case when is_returned
         then coalesce(nullif(initcap(trim(return_reason)), ''), 'Not Provided')
         else 'No Return' end                                                       as return_reason,
    case when is_cancelled
         then coalesce(nullif(initcap(trim(cancellation_reason)), ''), 'Not Provided')
         else 'Not Cancelled' end                                                   as cancellation_reason,

    -- base amounts
    gross_revenue,
    discount_amount,
    sales_after_discount,
    recognized_revenue,
    recognized_cogs,
    estimated_contribution_profit,            -- = GROSS PROFIT

   
    if(is_cancelled, gross_revenue, 0)                                              as cancelled_gross_revenue,
    -- uses UN-gated cost_of_goods_sold on purpose (recognized_cogs is 0 for cancelled lines)
    if(is_cancelled, sales_after_discount - cost_of_goods_sold, 0)                  as cancelled_potential_profit,
    recognized_discount_amount,
    if(is_high_discount, discount_amount, 0)                                        as high_discount_amount,

    -- EXPOSURE (subsets of recognized revenue, not additional loss)
    if(is_returned, recognized_revenue, 0)                                          as returned_revenue,
    if(is_returned, estimated_contribution_profit, 0)                               as returned_profit,
    if(is_late, recognized_revenue, 0)                                              as late_revenue,

  
    cast(is_cancelled as int64)             as is_cancelled_metric,
    cast(is_returned as int64)              as is_returned_metric,
    cast(is_late as int64)                  as is_late_metric,
    cast(is_delivery_measured as int64)     as is_delivery_measured_metric,
    cast(is_high_discount as int64)         as is_heavily_discounted_metric,
    cast(cancelled_with_other_flags as int64) as is_cancelled_with_other_flags_metric,


    cast(is_cancelled as int64) + cast(is_returned as int64)
      + cast(is_late as int64) + cast(is_high_discount as int64)                    as risk_flag_count,

    (is_cancelled or is_returned or is_late or is_high_discount)                    as is_any_risk_flag,

    case
      when is_cancelled then 'Cancelled'
      when cast(is_returned as int64) + cast(is_late as int64)
           + cast(is_high_discount as int64) >= 2 then 'Multiple Flags'
      when is_returned then 'Returned'
      when is_late then 'Late Delivery'
      when is_high_discount then 'High Discount'
      else 'No Flag'
    end                                                                             as risk_profile,

    case
      when is_cancelled then 1
      when cast(is_returned as int64) + cast(is_late as int64)
           + cast(is_high_discount as int64) >= 2 then 2
      when is_returned then 3
      when is_late then 4
      when is_high_discount then 5
      else 6
    end                                                                             as risk_profile_sort,

  
    if(not is_cancelled and (is_returned or is_late or is_high_discount),
       recognized_revenue, 0)                                                       as flagged_recognized_revenue,

    -- calendar
    order_date,
    date_trunc(order_date, month)                       as order_month,
    extract(year from order_date)                       as order_year,
    format_date('%Y-%m', order_date)                    as month_year_label,
    extract(year from order_date) * 100
      + extract(month from order_date)                  as year_month_sort

from flags