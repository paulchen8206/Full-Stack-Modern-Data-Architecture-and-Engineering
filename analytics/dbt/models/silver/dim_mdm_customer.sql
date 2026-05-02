select
  customer_id,
  customer_name,
  customer_email,
  customer_segment,
  currency,
  first_order_timestamp,
  last_order_timestamp,
  projected_order_count,
  projected_total_spent,
  projection_updated_at,
  updated_at
from {{ ref('stg_mdm_customer360') }}
