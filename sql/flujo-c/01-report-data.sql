WITH d AS (
  SELECT t.trip_id, t.trip_ref, t.status, o.customer_code, o.currency, o.agreed_amount,
         o.delivery_due, t.delivered_at, t.current_eta, t.wait_minutes
  FROM tmw.trips t
  JOIN tmw.orders o ON o.order_id = t.order_id
),
delivered AS (
  SELECT *, (delivered_at <= delivery_due) AS on_time FROM d WHERE status = 'delivered'
),
late AS (
  SELECT trip_ref, customer_code, 'entregado_tarde' AS tipo, status, delivery_due,
         delivered_at AS fecha_real,
         round(extract(epoch FROM (delivered_at - delivery_due)) / 60)::int AS minutos_tarde
  FROM delivered WHERE NOT on_time
  UNION ALL
  SELECT trip_ref, customer_code, 'en_curso_retrasado', status, delivery_due,
         current_eta,
         round(extract(epoch FROM (current_eta - delivery_due)) / 60)::int
  FROM d
  WHERE status IN ('dispatched', 'in_transit', 'delayed') AND current_eta > delivery_due
),
uninv AS (
  SELECT d.trip_ref, d.customer_code, d.agreed_amount AS monto, d.currency AS moneda,
         d.delivered_at AS entregado, i.invoice_ref,
         coalesce(i.status, 'sin_factura') AS estado_factura,
         floor(extract(epoch FROM (now() - d.delivered_at)) / 86400)::int AS dias_desde_entrega
  FROM delivered d
  LEFT JOIN sage.invoices i ON i.trip_id = d.trip_id
  WHERE i.invoice_id IS NULL OR i.status = 'draft'
),
wait_by AS (
  SELECT customer_code, count(*) AS viajes,
         round(avg(wait_minutes), 1) AS espera_prom_min,
         max(wait_minutes) AS espera_max_min,
         sum(wait_minutes) AS espera_total_min
  FROM delivered GROUP BY customer_code
)
SELECT
  (SELECT json_build_object(
      'entregas_totales', count(*),
      'entregas_a_tiempo', count(*) FILTER (WHERE on_time),
      'pct_a_tiempo', round(100.0 * count(*) FILTER (WHERE on_time) / nullif(count(*), 0), 1),
      'viajes_tarde', (SELECT count(*) FROM late),
      'entregas_sin_facturar', (SELECT count(*) FROM uninv),
      'espera_prom_min', round(avg(wait_minutes), 1),
      'espera_max_min', max(wait_minutes))
   FROM delivered) AS resumen,
  (SELECT coalesce(json_agg(l ORDER BY l.minutos_tarde DESC), '[]'::json) FROM late l) AS tarde,
  (SELECT coalesce(json_agg(u ORDER BY u.entregado), '[]'::json) FROM uninv u) AS sin_facturar,
  (SELECT coalesce(json_agg(w ORDER BY w.customer_code), '[]'::json) FROM wait_by w) AS espera_cliente;