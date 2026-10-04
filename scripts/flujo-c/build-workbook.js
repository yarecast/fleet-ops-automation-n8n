const XLSX = require('@e965/xlsx');
const r = $input.first().json;
const s = r.resumen;
const wb = XLSX.utils.book_new();

const resumen = [
  ['Metrica', 'Valor'],
  ['Entregas totales', s.entregas_totales],
  ['Entregas a tiempo', s.entregas_a_tiempo],
  ['Porcentaje a tiempo', s.pct_a_tiempo],
  ['Viajes tarde', s.viajes_tarde],
  ['Entregas sin facturar', s.entregas_sin_facturar],
  ['Espera promedio (min)', s.espera_prom_min],
  ['Espera maxima (min)', s.espera_max_min],
  ['Generado (UTC)', new Date().toISOString()]
];
const wsRes = XLSX.utils.aoa_to_sheet(resumen);
wsRes['!cols'] = [{ wch: 26 }, { wch: 28 }];
XLSX.utils.book_append_sheet(wb, wsRes, 'Resumen');

const add = (name, rows) => {
  const ws = XLSX.utils.json_to_sheet(rows.length ? rows : [{ info: 'Sin registros' }]);
  ws['!cols'] = Array.from({ length: 8 }, () => ({ wch: 22 }));
  XLSX.utils.book_append_sheet(wb, ws, name);
};
add('Viajes tarde', r.tarde);
add('Sin facturar', r.sin_facturar);
add('Espera por cliente', r.espera_cliente);

const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
const fileName = 'reporte-diario-' + new Date().toISOString().slice(0, 10) + '.xlsx';
const bin = await this.helpers.prepareBinaryData(
  buf, fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
return [{ json: { fileName: fileName, stats: s }, binary: { data: bin } }];