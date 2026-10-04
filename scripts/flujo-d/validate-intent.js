const req = $('Validate Request').first().json;
const r = $input.first().json;
const threshold = Number($env.ASK_CONFIDENCE_THRESHOLD) || 0.7;
const b64 = (o) => Buffer.from(JSON.stringify(o), 'utf8').toString('base64');

const check = (v, s) => {
  if (s.type === 'object') {
    if (v === null || typeof v !== 'object' || Array.isArray(v)) return false;
    for (const k of (s.required || [])) if (!(k in v)) return false;
    for (const k of Object.keys(v)) {
      if (s.properties && s.properties[k]) { if (!check(v[k], s.properties[k])) return false; }
      else if (s.additionalProperties === false) return false;
    }
    return true;
  }
  if (s.type === 'string') return typeof v === 'string' && (!s.enum || s.enum.includes(v));
  if (s.type === 'number') return typeof v === 'number' && isFinite(v);
  return false;
};

const reply = (route, httpStatus, response, log) => [{ json: { route: route, httpStatus: httpStatus, response: response, log: log } }];
const review = (source, reason, out) => reply('review', 202,
  { status: 'needs_review', message: 'La consulta fue enviada a revision humana.' },
  { code: 'ask_review_queued', level: 'info', queueSource: source, reason: reason,
    detailsB64: b64({ question: req.question, intent: out && out.intent, confidence: out && out.confidence, reason: reason }) });

const content = (r && r.message && typeof r.message.content === 'string') ? r.message.content : null;
if (content === null) return reply('error', 502, { status: 'error', message: 'Servicio no disponible' }, { code: 'ask_llm_error', level: 'error' });

let out = null;
try { out = JSON.parse(content); } catch (e) { out = null; }
if (out === null || !check(out, req.schema)) return review('schema_validation', 'invalid_model_output', null);
if (out.confidence < 0 || out.confidence > 1) return review('schema_validation', 'invalid_confidence', out);
if (out.intent === 'unknown') {
  return reply('unknown', 200, { status: 'out_of_scope', message: 'No puedo responder esa consulta.', available: Object.keys(req.spec) }, { code: 'ask_out_of_scope', level: 'info' });
}
if (out.confidence < threshold) return review('ai_low_confidence', 'low_confidence', out);

const spec = req.spec[out.intent];
const values = [];
const named = {};
for (const p of spec.params) {
  let v = out.params[p.name];
  v = (typeof v === 'string') ? v.trim() : '';
  if (p.upper) v = v.toUpperCase();
  if (v === '') {
    if (p.required) return review('schema_validation', 'invalid_params', out);
    values.push('');
    continue;
  }
  if (p.enum && !p.enum.includes(v)) return review('schema_validation', 'invalid_params', out);
  if (p.pattern && !new RegExp(p.pattern).test(v)) return review('schema_validation', 'invalid_params', out);
  if (p.pattern && !req.question.toUpperCase().includes(v)) return review('schema_validation', 'ungrounded_param', out);
  values.push(v);
  named[p.name] = v;
}
return [{ json: { route: 'query', intent: out.intent, sql: spec.sql, values: values, params: named, confidence: out.confidence } }];