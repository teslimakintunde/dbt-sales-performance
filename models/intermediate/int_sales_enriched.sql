
{{ config(materialized='table') }}

with sales as (
    select * from {{ ref('stg_sales') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

joined as (
    select
        s.*,
        p.product_name,
        p.product_category,
        p.subcategory,
        p.brand,
        p.is_active as product_is_active,
        p.supplier_code,
        c.gender,
        c.loyalty_tier,
        c.customer_segment,
        c.acquisition_channel,
        c.acquisition_campaign_id,
        c.signup_date as customer_signup_date
    from sales s
    left join products p
        on s.product_id = p.product_id
    left join customers c
        on s.customer_id = c.customer_id
),

calculated as (
    select
        *,

        quantity * unit_price as gross_revenue,

        quantity * unit_price
            * coalesce(discount_applied, 0)
            as discount_amount,

        quantity * unit_price
            * (1 - coalesce(discount_applied, 0))
            as sales_after_discount,

        quantity * unit_cost as cost_of_goods_sold,
        coalesce(shipping_cost, 0) as shipping_cost_amount,

        case
          when lower(delivery_status) = 'cancelled'
            or cancellation_reason is not null
            then true
          else false
        end as is_cancelled,

        case
          when actual_delivery is not null
            and estimated_delivery is not null
            then date_diff(actual_delivery, estimated_delivery, day)
          else null
        end as delivery_variance_days,

        case
          when actual_delivery is not null
            and estimated_delivery is not null
            then actual_delivery > estimated_delivery
          else null
        end as is_late_delivery

    from joined
)

select
    *,
    case
      when is_cancelled then 0
      else sales_after_discount
    end as recognized_revenue,

    case
      when is_cancelled then 0
      else coalesce(cost_of_goods_sold, 0)
           + shipping_cost_amount
    end as estimated_fulfillment_cost,

    case
      when is_cancelled then 0
      else sales_after_discount
           - coalesce(cost_of_goods_sold, 0)
           - shipping_cost_amount
    end as estimated_contribution_profit,

    safe_divide(
        case
          when is_cancelled then 0
          else sales_after_discount
               - coalesce(cost_of_goods_sold, 0)
               - shipping_cost_amount
        end,
        case
          when is_cancelled then 0
          else sales_after_discount
        end
    ) * 100 as estimated_contribution_margin_pct,

    case
      when discount_applied is null then 'Unknown'
      when discount_applied = 0 then 'No Discount'
      when discount_applied > 0 and discount_applied <= 0.05
        then 'Low (1–5%)'
      when discount_applied > 0.05 and discount_applied <= 0.10
        then 'Moderate (6–10%)'
      when discount_applied > 0.10 and discount_applied <= 0.15
        then 'High (11–15%)'
      when discount_applied > 0.15
        then 'Very High (Above 15%)'
      else 'Invalid Discount'
    end as discount_band
from calculated
