select
  product_id,
  product_name,
  currency,
  first_seen_at,
  last_seen_at,
  orders_count,
  units_sold,
  avg_unit_price,
  updated_at
from {{ ref('stg_mdm_product_master') }}
