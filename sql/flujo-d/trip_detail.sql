SELECT trip_ref, status, order_ref, customer_code, origin, destination, delivery_due, planned_eta,
       current_eta, delivered_at, wait_minutes, eta_deviation_min, is_late, operator_code, unit_code
FROM ai_views.v_trips
WHERE trip_ref = $1;