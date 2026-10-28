
{{ config(materialized='table') }}

with order_risk as (
    select
        order_id,

        any_value(customer_id) as customer_id,
        any_value(order_date) as order_date,
        any_value(region) as region,
        any_value(sales_channel) as sales_channel,

        count(*) as line_item_count,
        sum(gross_revenue) as gross_revenue,
        sum(recognized_revenue) as recognized_revenue,
        sum(estimated_contribution_profit) as estimated_contribution_profit,

        safe_divide(
          sum(discount_amount),
          sum(gross_revenue)
        ) * 100 as effective_discount_pct,

        logical_or(is_cancelled) as has_cancelled_line,
        logical_or(return_requested = true) as has_return_request,
        logical_or(is_late_delivery = true) as has_late_line,

        countif(return_requested = true) as return_requested_lines,
        countif(is_cancelled) as cancelled_lines,

        string_agg(
          distinct nullif(return_reason, ''),
          ', '
        ) as return_reasons,

        string_agg(
          distinct nullif(cancellation_reason, ''),
          ', '
        ) as cancellation_reasons,

        string_agg(
          distinct discount_band,
          ', '
        ) as discount_bands

    from {{ ref('int_sales_enriched') }}
    group by order_id
)

select
    *,

    case
      when has_cancelled_line then 'Cancellation Risk / Cancelled'
      when has_return_request then 'Return Requested'
      when effective_discount_pct > 15 then 'Very High Discount'
      when has_late_line then 'Late Delivery'
      else 'No Flag from Available Data'
    end as primary_commercial_risk_flag

from order_risk
