CREATE SCHEMA IF NOT EXISTS ai_views;

CREATE OR REPLACE VIEW ai_views.v_trips WITH (security_barrier = true) AS
SELECT t.trip_ref, t.status, o.order_ref, o.customer_code, o.origin, o.destination,
       o.delivery_due, t.planned_eta, t.current_eta, t.delivered_at,
       t.wait_minutes, t.eta_deviation_min,
       (COALESCE(t.delivered_at, t.current_eta) > o.delivery_due) AS is_late,
       op.operator_code, e.unit_code
FROM tmw.trips t
JOIN tmw.orders o ON o.order_id = t.order_id
LEFT JOIN tmw.operators op ON op.operator_id = t.operator_id
LEFT JOIN tmw.equipment e ON e.equipment_id = t.equipment_id;

CREATE OR REPLACE VIEW ai_views.v_invoices WITH (security_barrier = true) AS
SELECT i.invoice_ref, t.trip_ref, i.customer_code, i.amount, i.currency,
       i.status, i.reconciliation_status, i.created_at, i.reconciled_at
FROM sage.invoices i
JOIN tmw.trips t ON t.trip_id = i.trip_id;

CREATE OR REPLACE VIEW ai_views.v_delivered_unbilled WITH (security_barrier = true) AS
SELECT t.trip_ref, o.order_ref, o.customer_code, o.agreed_amount, o.currency, t.delivered_at
FROM tmw.trips t
JOIN tmw.orders o ON o.order_id = t.order_id
WHERE t.status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM sage.invoices i WHERE i.trip_id = t.trip_id);

CREATE OR REPLACE VIEW ai_views.v_review_queue WITH (security_barrier = true) AS
SELECT review_id, source, ref_type, ref_id, reason, status, created_at
FROM ops.review_queue;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA ai_views TO fleetops_readonly;
GRANT SELECT ON ai_views.v_trips, ai_views.v_invoices,
                ai_views.v_delivered_unbilled, ai_views.v_review_queue
TO fleetops_readonly;
