
{{ config(materialized='table') }}

with sales_velocity as (
    select
        product_id,
        sum(quantity) as total_units_sold,
        min(order_date) as first_recorded_order_date,
        max(order_date) as last_recorded_order_date
    from {{ ref('int_sales_enriched') }}
    where is_cancelled = false
    group by product_id
),

velocity_calculated as (
    select
        *,
        date_diff(
          last_recorded_order_date,
          first_recorded_order_date,
          day
        ) + 1 as observed_sales_window_days,

        safe_divide(
          total_units_sold,
          date_diff(
            last_recorded_order_date,
            first_recorded_order_date,
            day
          ) + 1
        ) as average_units_sold_per_day

    from sales_velocity
)

select
    p.product_id,
    p.product_name,
    p.product_category,
    p.is_active,
    p.current_stock_level,
    p.reorder_level,

    coalesce(v.total_units_sold, 0) as observed_units_sold,
    v.first_recorded_order_date,
    v.last_recorded_order_date,
    v.observed_sales_window_days,
    v.average_units_sold_per_day,

    safe_divide(
      p.current_stock_level,
      v.average_units_sold_per_day
    ) as estimated_days_of_stock_cover,

    case
      when p.current_stock_level is null or p.reorder_level is null
        then 'Insufficient Stock Data'
      when p.current_stock_level <= p.reorder_level
        then 'At or Below Reorder Level'
      when coalesce(v.average_units_sold_per_day, 0) = 0
        then 'No Recorded Sales'
      when safe_divide(
        p.current_stock_level,
        v.average_units_sold_per_day
      ) <= 7
        then 'Low Estimated Stock Cover'
      else 'No Immediate Stock Alert'
    end as inventory_risk_status

from {{ ref('stg_products') }} p
left join velocity_calculated v
  on p.product_id = v.product_id
