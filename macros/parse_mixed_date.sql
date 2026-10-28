{% macro parse_mixed_date(column_expression) %}
  case
    -- 1. Handle Nulls/Blanks Safely
    when nullif(trim(cast({{ column_expression }} as string)), '') is null then null

    -- 2. Master Case logic using clean strings with 'Sept' replaced inline
    else
      -- We create a local Jinja variable to hold the string base cleaning to keep things readable
      {% set clean_string = "regexp_replace(nullif(trim(cast(" ~ column_expression ~ " as string)), ''), r'(?i)-Sept-', '-Sep-')" %}
      
      case
        -- YYYY-MM-DD
        when regexp_contains({{ clean_string }}, r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
          then safe.parse_date('%Y-%m-%d', {{ clean_string }})

        -- DD-MMM-YYYY (e.g., 09-Jun-2024)
        when regexp_contains({{ clean_string }}, r'^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$')
          then safe.parse_date('%d-%b-%Y', {{ clean_string }})

        -- DD-MMM-YY (e.g., 09-Jun-24)
        when regexp_contains({{ clean_string }}, r'^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$')
          then safe.parse_date('%d-%b-%y', {{ clean_string }})

        -- DD-MM-YY (e.g., 25-10-26)
        when regexp_contains({{ clean_string }}, r'^[0-9]{2}-[0-9]{2}-[0-9]{2}$')
          then safe.parse_date('%d-%m-%y', {{ clean_string }})

        -- Slashes (M/D/YYYY or D/M/YYYY configurations)
        when regexp_contains({{ clean_string }}, r'^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$') then
          case 
            -- If first element (Day) > 12 -> dd/mm/yyyy
            when safe_cast(split({{ clean_string }}, '/')[safe_offset(0)] as int64) > 12
              then safe.parse_date('%d/%m/%Y', {{ clean_string }})
            
            -- If second element (Month) > 12 -> mm/dd/yyyy
            when safe_cast(split({{ clean_string }}, '/')[safe_offset(1)] as int64) > 12
              then safe.parse_date('%m/%d/%Y', {{ clean_string }})
            
            -- Fallback fallback if neither > 12 (ambiguous like 05/06/2024), default to US or standard
            else safe.parse_date('%m/%d/%Y', {{ clean_string }})
          end

        else null
      end
  end
{% endmacro %}
