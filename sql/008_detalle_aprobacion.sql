-- Aprobación recibo por recibo: cada fila de liquidacion_detalle (un recibo cobrado) se aprueba
-- por separado. Los que están tildados (aprobado = true) suman a la cuenta corriente del vendedor;
-- los no tildados quedan pendientes. liquidacion_vendedores.estado sigue existiendo y se mantiene
-- sincronizado ('aprobada' solo si TODOS los recibos del vendedor están aprobados).

alter table liquidacion_detalle add column if not exists aprobado boolean not null default false;
alter table liquidacion_detalle add column if not exists aprobado_por text;
alter table liquidacion_detalle add column if not exists aprobado_at timestamptz;

-- Backfill: los vendedores que ya estaban aprobados mantienen todos sus recibos aprobados.
update liquidacion_detalle d
   set aprobado = true, aprobado_por = g.revisado_por, aprobado_at = g.revisado_at
  from liquidacion_vendedores g
 where g.liquidacion_id = d.liquidacion_id
   and g.vendedor_nombre = d.vendedor_nombre
   and g.estado = 'aprobada';

create index if not exists idx_liq_detalle_aprobado on liquidacion_detalle(aprobado);
