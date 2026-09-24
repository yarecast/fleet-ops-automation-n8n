BEGIN;

INSERT INTO tmw.operators (operator_code, display_alias) VALUES
 ('OP-001','Operador Sintetico 1'),
 ('OP-002','Operador Sintetico 2'),
 ('OP-003','Operador Sintetico 3'),
 ('OP-004','Operador Sintetico 4'),
 ('OP-005','Operador Sintetico 5')
ON CONFLICT DO NOTHING;

INSERT INTO tmw.equipment (unit_code, equipment_type, samsara_vehicle_id) VALUES
 ('TR-101','tractor','900000000000101'),
 ('TR-102','tractor','900000000000102'),
 ('TR-103','tractor','900000000000103'),
 ('TR-104','tractor','900000000000104'),
 ('TR-105','tractor','900000000000105')
ON CONFLICT DO NOTHING;

INSERT INTO tmw.orders (order_ref, customer_code, origin, destination, agreed_amount, currency, delivery_due)
SELECT v.order_ref, v.customer_code, v.origin, v.destination, v.amount, 'USD', now() + make_interval(hours => v.due_h)
FROM (VALUES
 ('ORD-1001','CUST-A','Laredo, TX','Monterrey, NL',1500.00,-70),
 ('ORD-1002','CUST-B','Nuevo Laredo, TAM','San Antonio, TX',2200.50,-50),
 ('ORD-1003','CUST-A','Monterrey, NL','Dallas, TX',1800.00,-48),
 ('ORD-1004','CUST-C','Saltillo, COAH','Laredo, TX',2750.00,-30),
 ('ORD-1005','CUST-B','Reynosa, TAM','Houston, TX',990.00,-26),
 ('ORD-1006','CUST-C','Laredo, TX','Saltillo, COAH',3100.00,-10),
 ('ORD-1007','CUST-A','Monterrey, NL','San Antonio, TX',1250.00,-8),
 ('ORD-1008','CUST-B','Dallas, TX','Monterrey, NL',2400.00,6),
 ('ORD-1009','CUST-C','Houston, TX','Reynosa, TAM',1650.00,4),
 ('ORD-1010','CUST-A','San Antonio, TX','Nuevo Laredo, TAM',2000.00,30),
 ('ORD-1011','CUST-B','Laredo, TX','Monterrey, NL',1900.00,52),
 ('ORD-1012','CUST-C','Saltillo, COAH','Dallas, TX',1400.00,20)
) AS v(order_ref, customer_code, origin, destination, amount, due_h)
ON CONFLICT DO NOTHING;

INSERT INTO tmw.trips (trip_ref, order_id, operator_id, equipment_id, status,
                       planned_eta, current_eta, delivered_at, wait_minutes, eta_deviation_min)
SELECT v.trip_ref, o.order_id, op.operator_id, e.equipment_id, v.status,
  CASE WHEN v.status IN ('pending','cancelled') THEN NULL ELSE o.delivery_due END,
  CASE WHEN v.cur_h IS NULL THEN NULL ELSE now() + make_interval(hours => v.cur_h) END,
  CASE WHEN v.status = 'delivered' THEN now() + make_interval(hours => v.cur_h) END,
  v.wait_min,
  CASE WHEN v.cur_h IS NULL THEN NULL
       ELSE round(extract(epoch FROM (now() + make_interval(hours => v.cur_h) - o.delivery_due)) / 60)::int END
FROM (VALUES
 ('TRP-2001','ORD-1001','OP-001','TR-101','delivered',-72,30),
 ('TRP-2002','ORD-1002','OP-002','TR-102','delivered',-52,45),
 ('TRP-2003','ORD-1003','OP-003','TR-103','delivered',-40,120),
 ('TRP-2004','ORD-1004','OP-004','TR-104','delivered',-31,15),
 ('TRP-2005','ORD-1005','OP-005','TR-105','delivered',-20,90),
 ('TRP-2006','ORD-1006','OP-001','TR-101','delivered',-11,20),
 ('TRP-2007','ORD-1007','OP-002','TR-102','delivered',-5,75),
 ('TRP-2008','ORD-1008','OP-003','TR-103','in_transit',6,0),
 ('TRP-2009','ORD-1009','OP-004','TR-104','delayed',9,0),
 ('TRP-2010','ORD-1010','OP-005','TR-105','dispatched',30,0),
 ('TRP-2011','ORD-1011',NULL,NULL,'pending',NULL,0),
 ('TRP-2012','ORD-1012','OP-001',NULL,'cancelled',NULL,0)
) AS v(trip_ref, order_ref, op_code, unit_code, status, cur_h, wait_min)
JOIN tmw.orders o ON o.order_ref = v.order_ref
LEFT JOIN tmw.operators op ON op.operator_code = v.op_code
LEFT JOIN tmw.equipment e ON e.unit_code = v.unit_code
ON CONFLICT DO NOTHING;

INSERT INTO sage.invoices (invoice_ref, trip_id, customer_code, amount, currency)
SELECT v.invoice_ref, t.trip_id, o.customer_code, o.agreed_amount, o.currency
FROM (VALUES
 ('INV-3001','TRP-2001'),
 ('INV-3002','TRP-2002'),
 ('INV-3003','TRP-2003'),
 ('INV-3004','TRP-2004'),
 ('INV-3005','TRP-2005')
) AS v(invoice_ref, trip_ref)
JOIN tmw.trips t ON t.trip_ref = v.trip_ref
JOIN tmw.orders o ON o.order_id = t.order_id
ON CONFLICT DO NOTHING;

INSERT INTO sage.receivables (receivable_ref, customer_code, amount_due, amount_paid, status)
SELECT * FROM (VALUES
 ('REF-2001','CUST-A',1500.00,0.00,'open'),
 ('REF-2002','CUST-B',2200.50,0.00,'open'),
 ('REF-2003','CUST-A',1800.00,1000.00,'partial'),
 ('REF-2004','CUST-C',2750.00,0.00,'open'),
 ('REF-2004','CUST-C',2750.00,0.00,'open'),
 ('REF-9999','CUST-B',640.00,0.00,'open')
) AS v(receivable_ref, customer_code, amount_due, amount_paid, status)
WHERE NOT EXISTS (SELECT 1 FROM sage.receivables);

COMMIT;
