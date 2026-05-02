{% if target.type == 'postgres' %}
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
from landing.mdm_product_master
{% else %}
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
from warehouse.landing.mdm_product_master
{% endif %}
