
{{ config(materialized='view') }}

with source_sales as (
    select * from {{ source('raw_sales_data', 'sales') }}
),
cleaned as (
    select
        nullif(trim(cast(order_id as string)), '') as order_id,
        nullif(trim(cast(line_item_id as string)), '') as line_item_id,
        nullif(trim(cast(customer_id as string)), '') as customer_id,
        nullif(trim(cast(product_id as string)), '') as product_id,

        safe_cast(quantity as int64) as quantity,
        safe_cast(unit_price as numeric) as unit_price,
        safe_cast(unit_cost as numeric) as unit_cost,
        safe_cast(discount_applied as numeric) as discount_applied,
        safe_cast(shipping_cost as numeric) as shipping_cost,

        {{ parse_mixed_date('order_date') }} as order_date,
        {{ parse_mixed_date('estimated_delivery') }} as estimated_delivery,
        {{ parse_mixed_date('actual_delivery') }} as actual_delivery,

        case
          when lower(trim(cast(delivery_status as string)))
               in ('delivered', 'deliverd', 'delivred', 'deliverred')
            then 'Delivered'
          when lower(trim(cast(delivery_status as string)))
               in ('delayed', 'delayyed', 'delayd','Delaied')
            then 'Delayed'
          when lower(trim(cast(delivery_status as string)))
               in ('cancelled', 'canceled', 'cancled')
            then 'Cancelled'
          when lower(trim(cast(delivery_status as string))) = 'pending'
            then 'Pending'
          when lower(trim(cast(delivery_status as string))) = 'processing'
            then 'Processing'
          when nullif(trim(cast(delivery_status as string)), '') is null
            then 'Unknown'
          else initcap(trim(cast(delivery_status as string)))
        end as delivery_status,

        case
          when lower(trim(cast(payment_method as string)))
               in ('paypal', 'pay pal')
            then 'PayPal'
          when lower(trim(cast(payment_method as string)))
               in ('credit card', 'creditcard')
            then 'Credit Card'
          when lower(trim(cast(payment_method as string)))
               in ('bank transfer', 'banktransfer')
            then 'Bank Transfer'
          when lower(trim(cast(payment_method as string)))
               in ('debit card', 'debitcard')
            then 'Debit Card'
          when lower(trim(cast(payment_method as string))) = 'cash'
            then 'Cash'
          when nullif(trim(cast(payment_method as string)), '') is null
            then 'Unknown'
          else initcap(trim(cast(payment_method as string)))
        end as payment_method,

        nullif(trim(cast(region as string)), '') as region,
        nullif(trim(cast(sales_channel as string)), '') as sales_channel,
        nullif(trim(cast(notes as string)), '') as notes,
        nullif(trim(cast(campaign_id as string)), '') as campaign_id,
        nullif(trim(cast(shipping_city as string)), '') as shipping_city,
        nullif(trim(cast(warehouse_id as string)), '') as warehouse_id,
        nullif(trim(cast(order_priority as string)), '') as order_priority,
        nullif(trim(cast(return_reason as string)), '') as return_reason,
        nullif(trim(cast(cancellation_reason as string)), '') as cancellation_reason,

       
        return_requested,

      
        nullif(trim(cast(order_date as string)), '') is not null
          and {{ parse_mixed_date('order_date') }} is null
          as invalid_order_date,

        nullif(trim(cast(estimated_delivery as string)), '') is not null
          and {{ parse_mixed_date('estimated_delivery') }} is null
          as invalid_estimated_delivery,

        nullif(trim(cast(actual_delivery as string)), '') is not null
          and {{ parse_mixed_date('actual_delivery') }} is null
          as invalid_actual_delivery

    from source_sales
)

select * from cleaned
