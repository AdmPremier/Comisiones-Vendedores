-- Medios de pago de cada recibo (efectivo, transferencia, cheques, echeqs), para poder ver desde la
-- app "cómo pagó el cliente" al tocar un recibo. Los datos salen de Odoo (account.payment y
-- l10n_latam.check); hoy se cargan leyendo Odoo, y a futuro los trae la tarea programada.
-- Clave: (empresa, nro_pago) porque Magontex e Instatex pueden repetir nombres de pago.

create table if not exists recibos_pago (
  id bigint generated always as identity primary key,
  empresa text not null,
  nro_pago text not null,
  fecha date,
  cliente text,
  importe numeric,
  medio text,                              -- Cheque / Echeq / Efectivo / Transferencia
  diario text,                             -- diario de Odoo (banco, caja, cheques de terceros...)
  referencia text,                         -- memo / referencia del pago (ej. N° de operación)
  cheques jsonb not null default '[]'::jsonb,  -- [{numero, banco, fecha_cobro, importe}]
  fuente text not null default 'odoo',
  created_at timestamptz not null default now(),
  unique (empresa, nro_pago)
);

alter table recibos_pago enable row level security;
create policy "anon_all_recibos_pago" on recibos_pago for all to anon using (true) with check (true);
