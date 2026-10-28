
{{ config(materialized='table') }}

with customer_base as (
    select * from {{ ref('stg_customers') }}
),

customer_sales as (
    select
        customer_id,

        count(distinct case
          when is_cancelled = false then order_id
        end) as completed_order_count,

        sum(recognized_revenue) as historical_revenue,
        sum(estimated_contribution_profit) as historical_contribution_profit,
        sum(quantity) as units_ordered,

        min(order_date) as first_order_date,
        max(order_date) as last_order_date,

        countif(return_requested = true) as lines_with_return_requests

    from {{ ref('int_sales_enriched') }}
    group by customer_id
),

joined as (
    select
        c.*,
        coalesce(s.completed_order_count, 0) as completed_order_count,
        coalesce(s.historical_revenue, 0) as historical_revenue,
        coalesce(s.historical_contribution_profit, 0)
          as historical_contribution_profit,
        coalesce(s.units_ordered, 0) as units_ordered,
        s.first_order_date,
        s.last_order_date,
        coalesce(s.lines_with_return_requests, 0)
          as lines_with_return_requests,

        date_diff(
          (select max(order_date) from {{ ref('stg_sales') }}),
          s.last_order_date,
          day
        ) as recency_days

    from customer_base c
    left join customer_sales s
      on c.customer_id = s.customer_id
)

select
    *,

    safe_divide(historical_revenue, completed_order_count)
      as historical_average_order_value,

    case
      when completed_order_count = 0 then 'No Recorded Orders'
      when completed_order_count = 1 then 'One-Time Customer'
      else 'Repeat Customer'
    end as purchase_frequency_segment

from joined
