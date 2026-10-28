
{{ config(materialized='table') }}

with order_rollup as (
    select
        order_id,
        any_value(customer_id) as customer_id,
        any_value(region) as region,
        any_value(sales_channel) as sales_channel,
        any_value(warehouse_id) as warehouse_id,
        any_value(order_priority) as order_priority,

        min(order_date) as order_date,
        min(estimated_delivery) as estimated_delivery,
        max(actual_delivery) as actual_delivery,

        count(*) as line_item_count,
        sum(quantity) as total_units,

        logical_or(is_cancelled) as has_cancelled_line,

        logical_or(delivery_status = 'Delayed') as has_delayed_line,
        logical_and(delivery_status = 'Delivered') as all_lines_delivered,

        countif(actual_delivery is not null) as lines_with_actual_delivery,
        countif(estimated_delivery is not null) as lines_with_estimated_delivery

    from {{ ref('int_sales_enriched') }}
    group by order_id
)

select
    *,

    case
      when has_cancelled_line then 'Cancelled'
      when all_lines_delivered then 'Delivered'
      when has_delayed_line then 'Delayed'
      when actual_delivery is null then 'Not Yet Delivered'
      else 'In Progress / Other'
    end as order_delivery_status,

    date_diff(actual_delivery, order_date, day) as delivery_days,

    date_diff(actual_delivery, estimated_delivery, day)
      as delivery_variance_days,

    case
      when actual_delivery is null or estimated_delivery is null then null
      when actual_delivery > estimated_delivery then true
      else false
    end as is_late_order,

    case
      when actual_delivery is null or estimated_delivery is null then 'Incomplete'
      when actual_delivery > estimated_delivery then 'Late'
      else 'On Time'
    end as delivery_sla_result

from order_rollup
