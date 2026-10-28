
{{ config(materialized='view') }}
with source_products as (
    select * from {{ source('raw_sales_data', 'products') }}
)
select
    nullif(trim(cast(product_id as string)), '') as product_id,
    nullif(trim(cast(product_name as string)), '') as product_name,
    nullif(trim(cast(category as string)), '') as product_category,
    nullif(trim(cast(subcategory as string)), '') as subcategory,
    nullif(trim(cast(brand as string)), '') as brand,

    {{ parse_mixed_date('launch_date') }} as launch_date,
    {{ parse_mixed_date('discontinued_date') }} as discontinued_date,

    safe_cast(base_price as numeric) as base_price,
    safe_cast(unit_cost as numeric) as unit_cost,
    nullif(trim(cast(supplier_code as string)), '') as supplier_code,
    nullif(trim(cast(country_of_origin as string)), '') as country_of_origin,

   
    is_active,

    safe_cast(reorder_level as int64) as reorder_level,
    safe_cast(current_stock_level as int64) as current_stock_level,
    safe_cast(weight_kg as numeric) as weight_kg,
    nullif(trim(cast(seasonality_tag as string)), '') as seasonality_tag,
    safe_cast(avg_rating as numeric) as avg_rating,
    safe_cast(review_count as int64) as review_count,

    nullif(trim(cast(launch_date as string)), '') is not null
      and {{ parse_mixed_date('launch_date') }} is null
      as invalid_launch_date,

    nullif(trim(cast(discontinued_date as string)), '') is not null
      and {{ parse_mixed_date('discontinued_date') }} is null
      as invalid_discontinued_date

from source_products
