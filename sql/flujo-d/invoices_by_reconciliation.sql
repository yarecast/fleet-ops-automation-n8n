SELECT invoice_ref, trip_ref, customer_code, amount, currency, status, reconciliation_status
FROM ai_views.v_invoices
WHERE reconciliation_status = $1
ORDER BY created_at
LIMIT 50;