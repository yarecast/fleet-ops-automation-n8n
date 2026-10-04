WITH pending AS (
  SELECT invoice_id, invoice_ref, customer_code, amount, currency
  FROM sage.invoices
  WHERE reconciliation_status = 'pending' AND status = 'draft'
  FOR UPDATE
),
cand AS (
  SELECT p.invoice_id,
         count(r.receivable_id) AS n_cand,
         min(r.receivable_id) AS first_rid,
         array_agg(r.receivable_id ORDER BY r.receivable_id) FILTER (WHERE r.receivable_id IS NOT NULL) AS rids,
         max(r.amount_paid) AS paid
  FROM pending p
  LEFT JOIN sage.receivables r
    ON r.invoice_id IS NULL
   AND r.status IN ('open', 'partial')
   AND r.customer_code = p.customer_code
   AND r.currency = p.currency
   AND r.amount_due = p.amount
  GROUP BY p.invoice_id
),
classified AS (
  SELECT p.invoice_id, p.invoice_ref, p.customer_code, p.amount, p.currency,
         c.n_cand, c.first_rid, c.rids, c.paid,
         CASE WHEN c.n_cand = 0 THEN 'unmatched'
              WHEN c.n_cand > 1 THEN 'ambiguous'
              WHEN c.paid > 0 THEN 'partial'
              ELSE 'matched' END AS outcome
  FROM pending p
  JOIN cand c ON c.invoice_id = p.invoice_id
),
upd_inv AS (
  UPDATE sage.invoices i
  SET reconciliation_status = c.outcome,
      reconciled_at = CASE WHEN c.outcome = 'matched' THEN now() END
  FROM classified c
  WHERE i.invoice_id = c.invoice_id
  RETURNING i.invoice_id
),
link AS (
  UPDATE sage.receivables r
  SET invoice_id = c.invoice_id
  FROM classified c
  WHERE c.outcome = 'matched' AND r.receivable_id = c.first_rid
  RETURNING r.receivable_id
),
rq AS (
  INSERT INTO ops.review_queue (source, ref_type, ref_id, reason, details, status, is_synthetic)
  SELECT 'reconciliation', 'invoice', c.invoice_ref,
         CASE c.outcome WHEN 'unmatched' THEN 'no_match'
                        WHEN 'ambiguous' THEN 'ambiguous_match'
                        ELSE 'partial_payment' END,
         jsonb_build_object(
           'invoice_id', c.invoice_id,
           'customer_code', c.customer_code,
           'amount', c.amount,
           'currency', c.currency,
           'candidate_receivable_ids', coalesce(to_jsonb(c.rids), '[]'::jsonb),
           'amount_paid', c.paid),
         'pending', true
  FROM classified c
  WHERE c.outcome <> 'matched'
    AND NOT EXISTS (
      SELECT 1 FROM ops.review_queue q
      WHERE q.source = 'reconciliation' AND q.ref_type = 'invoice'
        AND q.ref_id = c.invoice_ref AND q.status = 'pending')
  RETURNING review_id
)
SELECT
  (SELECT count(*) FROM classified) AS processed,
  (SELECT count(*) FROM classified WHERE outcome = 'matched') AS matched,
  (SELECT count(*) FROM classified WHERE outcome = 'partial') AS partial,
  (SELECT count(*) FROM classified WHERE outcome = 'ambiguous') AS ambiguous,
  (SELECT count(*) FROM classified WHERE outcome = 'unmatched') AS unmatched,
  (SELECT count(*) FROM rq) AS queued,
  (SELECT count(*) FROM link) AS linked,
  (SELECT count(*) FROM upd_inv) AS updated;