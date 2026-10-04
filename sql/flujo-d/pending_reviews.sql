SELECT review_id, source, ref_type, ref_id, reason, created_at
FROM ai_views.v_review_queue
WHERE status = 'pending' AND ($1 = '' OR source = $1)
ORDER BY created_at
LIMIT 50;