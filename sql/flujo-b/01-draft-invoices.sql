WITH eligible AS (
  SELECT t.trip_id, o.customer_code, o.agreed_amount, o.currency
  FROM tmw.trips t
  JOIN tmw.orders o ON o.order_id = t.order_id
  WHERE t.status = 'delivered'
    AND NOT EXISTS (SELECT 1 FROM sage.invoices i WHERE i.trip_id = t.trip_id)
)
INSERT INTO sage.invoices
  (invoice_ref, trip_id, customer_code, amount, currency, status, reconciliation_status, is_synthetic)
SELECT
  'INV-' || (3000 + (SELECT coalesce(max(invoice_id), 0) FROM sage.invoices) + row_number() OVER (ORDER BY e.trip_id)),
  e.trip_id, e.customer_code, e.agreed_amount, e.currency, 'draft', 'pending', true
FROM eligible e
ON CONFLICT (trip_id) DO NOTHING
RETURNING invoice_id, invoice_ref, trip_id, amount;