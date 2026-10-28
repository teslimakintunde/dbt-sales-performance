
{{ config(materialized='table') }}

with customer_cohorts as (
    select
        customer_id,
        date_trunc(signup_date, month) as signup_month,
        coalesce(acquisition_channel, 'Unknown') as acquisition_channel,
        coalesce(acquisition_campaign_id, 'Unknown') as acquisition_campaign_id
    from {{ ref('stg_customers') }}
),

customer_values as (
    select
        customer_id,
        historical_revenue,
        historical_contribution_profit,
        completed_order_count
    from {{ ref('fct_customer_value') }}
)

select
    c.signup_month,
    c.acquisition_channel,
    c.acquisition_campaign_id,

    count(distinct c.customer_id) as acquired_customers,

    countif(coalesce(v.completed_order_count, 0) > 0)
      as customers_with_orders,

    countif(coalesce(v.completed_order_count, 0) > 1)
      as repeat_customers,

    sum(coalesce(v.historical_revenue, 0)) as historical_revenue,
    sum(coalesce(v.historical_contribution_profit, 0))
      as historical_contribution_profit,

    safe_divide(
      countif(coalesce(v.completed_order_count, 0) > 1),
      count(distinct c.customer_id)
    ) * 100 as repeat_customer_rate_pct,

    safe_divide(
      sum(coalesce(v.historical_revenue, 0)),
      count(distinct c.customer_id)
    ) as historical_revenue_per_acquired_customer

from customer_cohorts c
left join customer_values v
  on c.customer_id = v.customer_id

group by
    c.signup_month,
    c.acquisition_channel,
    c.acquisition_campaign_id
