
{{ config(materialized='table') }}

with product_sales as (
    select
        product_id,

        count(distinct order_id) as order_count,
        sum(quantity) as units_sold,
        sum(recognized_revenue) as recognized_revenue,
        sum(estimated_contribution_profit) as estimated_contribution_profit,
        sum(discount_amount) as discount_amount,
        countif(return_requested = true) as lines_with_return_requests,
        avg(delivery_variance_days) as avg_delivery_variance_days

    from {{ ref('int_sales_enriched') }}
    group by product_id
)

select
    p.product_id,
    p.product_name,
    p.product_category,
    p.subcategory,
    p.brand,
    p.is_active,
    p.base_price,
    p.unit_cost,
    p.current_stock_level,
    p.reorder_level,
    p.avg_rating,
    p.review_count,

    coalesce(s.order_count, 0) as order_count,
    coalesce(s.units_sold, 0) as units_sold,
    coalesce(s.recognized_revenue, 0) as recognized_revenue,
    coalesce(s.estimated_contribution_profit, 0)
      as estimated_contribution_profit,
    coalesce(s.discount_amount, 0) as discount_amount,
    coalesce(s.lines_with_return_requests, 0)
      as lines_with_return_requests,
    s.avg_delivery_variance_days,

    safe_divide(
      s.estimated_contribution_profit,
      s.recognized_revenue
    ) * 100 as estimated_contribution_margin_pct

from {{ ref('stg_products') }} p
left join product_sales s
  on p.product_id = s.product_id
