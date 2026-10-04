SELECT trip_ref, order_ref, customer_code, agreed_amount, currency, delivered_at
FROM ai_views.v_delivered_unbilled
WHERE ($1 = '' OR customer_code = $1)
ORDER BY delivered_at
LIMIT 50;