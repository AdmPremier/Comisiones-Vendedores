-- La aprobación deja de ser todo-o-nada por mes: ahora cada vendedor dentro de
-- una liquidación se aprueba/rechaza por separado (así un caso raro de un
-- vendedor no frena a los otros 16). liquidaciones.estado/revisado_por/etc.
-- quedan sin uso a partir de acá (no se borran, por las dudas), la app ya no
-- los toca.

create table if not exists liquidacion_vendedores (
  id bigint generated always as identity primary key,
  liquidacion_id bigint not null references liquidaciones(id) on delete cascade,
  vendedor_nombre text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobada','rechazada')),
  revisado_por text,
  revisado_at timestamptz,
  motivo_rechazo text,
  created_at timestamptz not null default now(),
  unique (liquidacion_id, vendedor_nombre)
);

alter table liquidacion_vendedores enable row level security;
create policy "anon_all_liquidacion_vendedores" on liquidacion_vendedores for all to anon using (true) with check (true);
create index if not exists idx_liq_vend_liq on liquidacion_vendedores(liquidacion_id);
create index if not exists idx_liq_vend_vendedor on liquidacion_vendedores(vendedor_nombre);

-- Backfill: crea una fila por cada vendedor que aparece en liquidaciones ya
-- cargadas (en Detalle o en Sin Comisión), heredando el estado que tenía la
-- liquidación completa hasta ahora.
insert into liquidacion_vendedores (liquidacion_id, vendedor_nombre, estado, revisado_por, revisado_at, motivo_rechazo)
select distinct l.id, d.vendedor_nombre, l.estado, l.revisado_por, l.revisado_at, l.motivo_rechazo
from liquidaciones l
join liquidacion_detalle d on d.liquidacion_id = l.id
where d.vendedor_nombre is not null and d.vendedor_nombre <> ''
on conflict (liquidacion_id, vendedor_nombre) do nothing;

insert into liquidacion_vendedores (liquidacion_id, vendedor_nombre, estado, revisado_por, revisado_at, motivo_rechazo)
select distinct l.id, s.vendedor_nombre, l.estado, l.revisado_por, l.revisado_at, l.motivo_rechazo
from liquidaciones l
join liquidacion_sin_comision s on s.liquidacion_id = l.id
where s.vendedor_nombre is not null and s.vendedor_nombre <> ''
on conflict (liquidacion_id, vendedor_nombre) do nothing;
