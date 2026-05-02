{% if target.type == 'postgres' %}
select
  date_key,
  full_date,
  day_of_month,
  day_of_week,
  day_name,
  week_of_year,
  month_of_year,
  month_name,
  quarter_of_year,
  year_number,
  is_weekend,
  created_at,
  updated_at
from landing.mdm_date
{% else %}
select
  date_key,
  full_date,
  day_of_month,
  day_of_week,
  day_name,
  week_of_year,
  month_of_year,
  month_name,
  quarter_of_year,
  year_number,
  is_weekend,
  created_at,
  updated_at
from warehouse.landing.mdm_date
{% endif %}
