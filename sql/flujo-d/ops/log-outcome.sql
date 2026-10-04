WITH q AS (
  INSERT INTO ops.review_queue (source, ref_type, ref_id, reason, details, status, is_synthetic)
  SELECT $4, 'ai_question', $3, $5,
         CASE WHEN $6 = '' THEN '{}'::jsonb ELSE convert_from(decode($6, 'base64'), 'UTF8')::jsonb END,
         'pending', true
  WHERE $4 <> ''
  RETURNING review_id
)
INSERT INTO ops.logs (level, workflow, event_code, execution_id, is_synthetic)
VALUES ($2, 'flujo-d-ask', $1, $3, true)
RETURNING log_id, (SELECT count(*) FROM q) AS queued;