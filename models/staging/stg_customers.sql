
{{ config(materialized='view') }}

with source_customers as (
    select * from {{ source('raw_sales_data', 'customers') }}
)

select
    nullif(trim(cast(customer_id as string)), '') as customer_id,
    nullif(trim(full_name), '') as full_name,
    nullif(trim(email), '') as email,

   
    nullif(trim(cast(phone_number as string)), '') as phone_number,

    {{ parse_mixed_date('signup_date') }} as signup_date,

    case
      when lower(trim(gender)) in ('female', 'femal', 'femle', 'f')
        then 'Female'
      when lower(trim(gender)) in ('male', 'm')
        then 'Male'
      when nullif(trim(gender), '') is null
        then 'Unknown'
      else initcap(trim(gender))
    end as gender,

    nullif(trim(city), '') as city,
    nullif(trim(region), '') as customer_region,

    case
      when lower(trim(loyalty_tier)) in ('silver', 'silvr')
        then 'Silver'
      when lower(trim(loyalty_tier)) in ('gold', 'gld')
        then 'Gold'
      when lower(trim(loyalty_tier)) in ('platinum', 'platnum')
        then 'Platinum'
      when lower(trim(loyalty_tier)) in ('bronze', 'brnze')
        then 'Bronze'
      when nullif(trim(loyalty_tier), '') is null
        then 'Unknown'
      else initcap(trim(loyalty_tier))
    end as loyalty_tier,

    case
      when lower(trim(preferred_payment))
           in ('creditcard', 'credit card')
        then 'Credit Card'
      when lower(trim(preferred_payment))
           in ('paypal', 'pay pal')
        then 'PayPal'
      when lower(trim(preferred_payment))
           in ('banktransfer', 'bank transfer')
        then 'Bank Transfer'
      when lower(trim(preferred_payment))
           in ('debit card', 'debitcard')
        then 'Debit Card'
      when lower(trim(preferred_payment)) = 'cash'
        then 'Cash'
      when nullif(trim(preferred_payment), '') is null
        then 'Unknown'
      else initcap(trim(preferred_payment))
    end as preferred_payment,

    safe_cast(age as int64) as customer_age,
    nullif(trim(customer_segment), '') as customer_segment,
    nullif(trim(acquisition_channel), '') as acquisition_channel,
    nullif(trim(acquisition_campaign_id), '') as acquisition_campaign_id,


    marketing_opt_in,

    safe_cast(credit_limit as numeric) as credit_limit,

    nullif(trim(cast(signup_date as string)), '') is not null
      and {{ parse_mixed_date('signup_date') }} is null
      as invalid_signup_date

from source_customers
