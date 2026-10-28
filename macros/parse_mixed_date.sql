{% macro parse_mixed_date(column_expression) %}
  case
    when nullif(trim(cast({{ column_expression }} as string)), '') is null then null

    -- ISO format: 2024-06-09
    when regexp_contains(nullif(trim(cast({{ column_expression }} as string)), ''), r'^\d{4}-\d{2}-\d{2}$')
      then safe.parse_date('%Y-%m-%d', nullif(trim(cast({{ column_expression }} as string)), ''))

    -- Text month: 09-Jun-24 or 09-Jun-2024
    when regexp_contains(nullif(trim(cast({{ column_expression }} as string)), ''), r'^\d{1,2}-[A-Za-z]{3,4}-\d{2}$')
      then safe.parse_date('%d-%b-%y', regexp_replace(nullif(trim(cast({{ column_expression }} as string)), ''), r'(?i)-Sept-', '-Sep-'))

    when regexp_contains(nullif(trim(cast({{ column_expression }} as string)), ''), r'^\d{1,2}-[A-Za-z]{3,4}-\d{4}$')
      then safe.parse_date('%d-%b-%Y', regexp_replace(nullif(trim(cast({{ column_expression }} as string)), ''), r'(?i)-Sept-', '-Sep-'))

    -- Numeric day-month-year, e.g. 25-10-26
    when regexp_contains(nullif(trim(cast({{ column_expression }} as string)), ''), r'^\d{1,2}-\d{1,2}-\d{2}$')
      then safe.parse_date('%d-%m-%y', nullif(trim(cast({{ column_expression }} as string)), ''))

    -- Slash dates: explicitly apply the chosen convention
    when regexp_contains(nullif(trim(cast({{ column_expression }} as string)), ''), r'^\d{1,2}/\d{1,2}/\d{4}$')
      then case
        when safe_cast(split(nullif(trim(cast({{ column_expression }} as string)), ''), '/')[safe_offset(0)] as int64) > 12
          then safe.parse_date('%d/%m/%Y', nullif(trim(cast({{ column_expression }} as string)), ''))
        else safe.parse_date('%m/%d/%Y', nullif(trim(cast({{ column_expression }} as string)), ''))
      end

    else null
  end
{% endmacro %}
