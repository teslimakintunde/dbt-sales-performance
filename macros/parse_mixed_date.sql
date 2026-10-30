
{% macro parse_mixed_date(column_expression) %}
  {%- set amb = var('ambiguous_date_order', 'mdy') -%}
  {%- set s = "regexp_replace(regexp_replace(trim(cast(" ~ column_expression ~ " as string)), r'(?i)-Sept-', '-Sep-'), r'[ T][0-9]{1,2}:[0-9]{2}.*$', '')" -%}
  case
    when nullif({{ s }}, '') is null then null

    -- YYYY-MM-DD
    when regexp_contains({{ s }}, r'^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$')
      then safe.parse_date('%Y-%m-%d', {{ s }})

    -- DD-MMM-YYYY
    when regexp_contains({{ s }}, r'^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}$')
      then safe.parse_date('%d-%b-%Y', {{ s }})

    -- DD-MMM-YY
    when regexp_contains({{ s }}, r'^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$')
      then safe.parse_date('%d-%b-%y', {{ s }})

    -- DD-MM-YY
    when regexp_contains({{ s }}, r'^[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}$')
      then safe.parse_date('%d-%m-%y', {{ s }})

    -- slashes, 4-digit year
    when regexp_contains({{ s }}, r'^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$') then
      case
        when safe_cast(split({{ s }}, '/')[safe_offset(0)] as int64) > 12
          then safe.parse_date('%d/%m/%Y', {{ s }})
        when safe_cast(split({{ s }}, '/')[safe_offset(1)] as int64) > 12
          then safe.parse_date('%m/%d/%Y', {{ s }})
        {% if amb == 'dmy' -%}
        else safe.parse_date('%d/%m/%Y', {{ s }})
        {%- elif amb == 'null' -%}
        else null
        {%- else -%}
        else safe.parse_date('%m/%d/%Y', {{ s }})
        {%- endif %}
      end

    -- slashes, 2-digit year
    when regexp_contains({{ s }}, r'^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}$') then
      case
        when safe_cast(split({{ s }}, '/')[safe_offset(0)] as int64) > 12
          then safe.parse_date('%d/%m/%y', {{ s }})
        when safe_cast(split({{ s }}, '/')[safe_offset(1)] as int64) > 12
          then safe.parse_date('%m/%d/%y', {{ s }})
        {% if amb == 'dmy' -%}
        else safe.parse_date('%d/%m/%y', {{ s }})
        {%- elif amb == 'null' -%}
        else null
        {%- else -%}
        else safe.parse_date('%m/%d/%y', {{ s }})
        {%- endif %}
      end

    else null
  end
{% endmacro %}