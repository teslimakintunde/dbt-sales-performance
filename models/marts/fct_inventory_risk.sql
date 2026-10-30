{{ config(materialized='table') }}

with max_sales_anchor as (
    select max(order_date) as max_system_order_date 
    from {{ ref('int_sales_enriched') }}
),

sales_velocity_30d as (
    select
        s.product_id,
        sum(s.quantity) as trailing_30d_units_sold,
        -- Calculate accurate run rate over a strict operational horizon
        safe_divide(sum(s.quantity), 30.0) as average_units_sold_per_day
    from {{ ref('int_sales_enriched') }} s
    cross join max_sales_anchor m
    where s.is_cancelled = false
      -- Constrain velocity calculation window for inventory forecasting responsiveness
      and s.order_date >= date_add(m.max_system_order_date, interval -30 day)
    group by s.product_id
)

select
    p.product_id,
    p.product_name,
    p.product_category,
    p.subcategory,
    p.brand,
    p.is_active,
    coalesce(p.current_stock_level, 0) as current_stock_level,
    coalesce(p.reorder_level, 0) as reorder_level,

    coalesce(v.trailing_30d_units_sold, 0) as trailing_30d_units_sold,
    coalesce(v.average_units_sold_per_day, 0.0) as average_units_sold_per_day,

    coalesce(
      safe_divide(p.current_stock_level, v.average_units_sold_per_day), 
      999 -- Used a clear placeholder out-of-bounds index for products with 0 sales velocity
    ) as estimated_days_of_stock_cover,

    -- Risk classifications mapped natively for visual engine mapping
    case
      when p.current_stock_level is null or p.reorder_level is null
        then 'Insufficient Stock Data'
      when p.current_stock_level = 0
        then 'Stockout / Out of Stock'
      when p.current_stock_level <= p.reorder_level
        then 'At or Below Reorder Level'
      when coalesce(v.average_units_sold_per_day, 0) = 0
        then 'No Recorded Sales (Trailing 30D)'
      when safe_divide(p.current_stock_level, v.average_units_sold_per_day) <= 7
        then 'Critical Low Cover (Under 7 Days)'
      else 'Healthy Stock Level'
    end as inventory_risk_status

from {{ ref('stg_products') }} p
left join sales_velocity_30d v
  on p.product_id = v.product_id
