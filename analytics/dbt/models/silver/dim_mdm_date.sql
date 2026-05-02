select
  date_key,
  full_date as order_date,
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
from {{ ref('stg_mdm_date') }}
