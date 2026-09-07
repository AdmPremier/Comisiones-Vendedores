-- Esquema inicial para "Comisiones de Vendedores" (Magontex / Instatex).
-- Correr una sola vez en el SQL Editor de un proyecto nuevo de Supabase.
--
-- La app usa la clave "anon" para leer/escribir directo desde el navegador
-- (sin auth real de Supabase, login propio a nivel app) — mismo patrón que
-- Hemkam-Laura. Por eso cada tabla tiene RLS habilitado con una policy
-- abierta para "anon".

-- ------------------------------------------------------------------
-- Vendedores: tabla de referencia con % vigente por etiqueta de Odoo.
-- "Ruben 7.5%" y "Ruben 10%" son dos filas distintas (misma persona,
-- dos etiquetas/tasas según el cliente) — ver spec sección 3.
-- ------------------------------------------------------------------
create table if not exists vendedores (
  id bigint generated always as identity primary key,
  etiqueta_odoo text not null unique,   -- tal cual figura en category_id de Odoo, ej: "Ruben 7.5%"
  nombre_mostrar text not null,         -- nombre para mostrar en la app, ej: "Ruben (7,5%)"
  pct_comision numeric not null,        -- ej: 5 (=5%)
  activo boolean not null default true,
  orden int,
  created_at timestamptz not null default now()
);

alter table vendedores enable row level security;
create policy "anon_all_vendedores" on vendedores for all to anon using (true) with check (true);

insert into vendedores (etiqueta_odoo, nombre_mostrar, pct_comision, orden) values
  ('Ruben 7.5%',         'Ruben (7,5%)',        7.5, 1),
  ('Ruben 10%',          'Ruben (10%)',         10,  2),
  ('Damian Giagante',    'Damian Giagante',     7.5, 3),
  ('Laura Aguado',       'Laura Aguado',        30,  4),
  ('Marcos Fachinni',    'Marcos Fachinni',     5,   5),
  ('Dario Firmani',      'Dario Firmani',       3,   6),
  ('Julio Benegas',      'Julio Benegas',       5,   7),
  ('Nicolas Tarantino',  'Nicolas Tarantino',   5,   8),
  ('Joaquin Martianez',  'Joaquin Martianez',   5,   9),
  ('Victor Budna',       'Victor Budna',        5,   10),
  ('Pascual Mazza',      'Pascual Mazza',       5,   11),
  ('Marcelo Carcagno',   'Marcelo Carcagno',    5,   12),
  ('Dario Sanabria',     'Dario Sanabria',      5,   13),
  ('Diego Gorostegui',   'Diego Gorostegui',    5,   14),
  ('Adrian Benardoni',   'Adrian Benardoni',    5,   15),
  ('Javier Ojeda',       'Javier Ojeda',        5,   16),
  ('Pablo Palacios',     'Pablo Palacios',      5,   17)
on conflict (etiqueta_odoo) do nothing;

-- ------------------------------------------------------------------
-- Liquidaciones: una fila por mes cargado (el Excel que produce la
-- tarea programada de Odoo/Claude).
-- ------------------------------------------------------------------
create table if not exists liquidaciones (
  id bigint generated always as identity primary key,
  mes int not null,                     -- 1-12, mes que se está liquidando (ej: comisión de agosto -> mes=8)
  anio int not null,
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobada','rechazada')),
  archivo_nombre text,
  cargado_por text,
  created_at timestamptz not null default now(),
  revisado_por text,
  revisado_at timestamptz,
  motivo_rechazo text,
  unique (mes, anio)
);

alter table liquidaciones enable row level security;
create policy "anon_all_liquidaciones" on liquidaciones for all to anon using (true) with check (true);

-- ------------------------------------------------------------------
-- Detalle - Comisión Calculada (hoja 2 del Excel): un pago comisionado.
-- ------------------------------------------------------------------
create table if not exists liquidacion_detalle (
  id bigint generated always as identity primary key,
  liquidacion_id bigint not null references liquidaciones(id) on delete cascade,
  vendedor_nombre text not null,        -- texto tal cual columna "Vendedor" del Excel (= vendedores.nombre_mostrar cuando matchea; no es FK dura para no perder datos si aparece un nombre nuevo)
  empresa text,
  fecha_pago date,
  cliente text,
  nro_pago text,
  tipo_doc text,                        -- 'Factura' / 'NOF'
  nro_documento text,
  importe_pago numeric,
  neto_documento numeric,
  total_documento numeric,
  base_comisionable numeric,
  pct_comision numeric,
  comision_a_pagar numeric
);

alter table liquidacion_detalle enable row level security;
create policy "anon_all_liquidacion_detalle" on liquidacion_detalle for all to anon using (true) with check (true);
create index if not exists idx_liq_detalle_liq on liquidacion_detalle(liquidacion_id);
create index if not exists idx_liq_detalle_vendedor on liquidacion_detalle(vendedor_nombre);
create index if not exists idx_liq_detalle_cliente on liquidacion_detalle(cliente);

-- ------------------------------------------------------------------
-- Sin Comisión - Revisar (hoja 3): pagos de vendedores válidos que no
-- se pudieron comisionar (anticipos sin aplicar, saldos migración, etc).
-- ------------------------------------------------------------------
create table if not exists liquidacion_sin_comision (
  id bigint generated always as identity primary key,
  liquidacion_id bigint not null references liquidaciones(id) on delete cascade,
  vendedor_nombre text,
  empresa text,
  fecha_pago date,
  cliente text,
  nro_pago text,
  motivo text,
  importe numeric,
  aplica text                            -- columna "Aplica" del Excel real (ej: "50/50", "RM", "FC", "CHR", "N/C") — significado a confirmar con Diego
);

alter table liquidacion_sin_comision enable row level security;
create policy "anon_all_liquidacion_sin_comision" on liquidacion_sin_comision for all to anon using (true) with check (true);
create index if not exists idx_liq_sc_liq on liquidacion_sin_comision(liquidacion_id);

-- ------------------------------------------------------------------
-- Excluidos (hoja 4): pagos de clientes con etiqueta excluida, sin
-- etiqueta, o con etiqueta desconocida.
-- ------------------------------------------------------------------
create table if not exists liquidacion_excluidos (
  id bigint generated always as identity primary key,
  liquidacion_id bigint not null references liquidaciones(id) on delete cascade,
  cliente text,
  motivo text,
  empresa text,
  fecha_pago date,
  nro_pago text,
  importe numeric
);

alter table liquidacion_excluidos enable row level security;
create policy "anon_all_liquidacion_excluidos" on liquidacion_excluidos for all to anon using (true) with check (true);
create index if not exists idx_liq_exc_liq on liquidacion_excluidos(liquidacion_id);

-- ------------------------------------------------------------------
-- Pagos a vendedores: para la cuenta corriente.
-- Saldo del vendedor = SUM(liquidacion_detalle.comision_a_pagar) de
-- liquidaciones en estado 'aprobada' donde vendedor_nombre = la suya
-- MENOS SUM(pagos_vendedor.importe).
-- ------------------------------------------------------------------
create table if not exists pagos_vendedor (
  id bigint generated always as identity primary key,
  vendedor_nombre text not null,        -- = vendedores.nombre_mostrar
  fecha date not null default current_date,
  importe numeric not null,
  nota text,
  registrado_por text,
  created_at timestamptz not null default now()
);

alter table pagos_vendedor enable row level security;
create policy "anon_all_pagos_vendedor" on pagos_vendedor for all to anon using (true) with check (true);
create index if not exists idx_pagos_vendedor on pagos_vendedor(vendedor_nombre);

-- ------------------------------------------------------------------
-- Implementaciones: buzón de pedidos de mejora (mismo patrón que
-- Hemkam-Laura y "Carga de cheques con CP").
-- ------------------------------------------------------------------
create table if not exists implementaciones (
  id bigint generated always as identity primary key,
  nombre text not null,
  titulo text not null,
  descripcion text not null,
  estado text not null default 'pendiente' check (estado in ('pendiente','realizada')),
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table implementaciones enable row level security;
create policy "anon_all_implementaciones" on implementaciones for all to anon using (true) with check (true);

-- ------------------------------------------------------------------
-- Aprobación por vendedor dentro de cada liquidación (no todo-o-nada por
-- mes): liquidaciones.estado/revisado_por/revisado_at/motivo_rechazo quedan
-- sin uso desde acá, la app ya no los toca — ver sql/004_liquidacion_vendedores.sql.
-- ------------------------------------------------------------------
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
