SELECT trip_ref, status, customer_code, delivery_due, current_eta, delivered_at, eta_deviation_min
FROM ai_views.v_trips
WHERE is_late
ORDER BY eta_deviation_min DESC NULLS LAST
LIMIT 50;