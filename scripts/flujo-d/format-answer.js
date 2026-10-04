const meta = $('Validate Intent').first().json;
const items = $input.all().map((i) => i.json);
if (items.some((j) => j && j.error)) {
  return [{ json: { httpStatus: 500, response: { status: 'error', message: 'Error interno' }, log: { code: 'ask_query_error', level: 'error' } } }];
}
const TITLES = {
  trips_by_status: 'Viajes por estado',
  late_trips: 'Viajes con retraso',
  trip_detail: 'Detalle del viaje',
  unbilled_deliveries: 'Entregas sin facturar',
  invoices_by_reconciliation: 'Facturas por estado de conciliacion',
  pending_reviews: 'Items pendientes en revision'
};
const rows = items.filter((j) => j && Object.keys(j).length > 0).slice(0, 50);
const lines = rows.map((r) => Object.values(r).filter((v) => v !== null && v !== '').join(' | '));
const interp = meta.intent + Object.keys(meta.params || {}).map((k) => ' ' + k + '=' + meta.params[k]).join('');
const answer = 'Interpretacion: ' + interp + '\n' + TITLES[meta.intent] + ': ' + rows.length + ' resultado(s).' + (lines.length ? '\n' + lines.join('\n') : '');
return [{ json: { httpStatus: 200, response: { status: 'ok', intent: meta.intent, interpreted: interp, count: rows.length, answer: answer, rows: rows }, log: { code: 'ask_answered', level: 'info' } } }];