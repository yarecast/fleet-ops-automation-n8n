SELECT trip_ref, status, customer_code, origin, destination, delivery_due, delivered_at, is_late
FROM ai_views.v_trips
WHERE status = $1
ORDER BY delivery_due
LIMIT 50;