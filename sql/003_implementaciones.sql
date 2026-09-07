-- "Implementaciones": buzón de pedidos de mejora, mismo patrón que ya usan
-- Hemkam-Laura y "Carga de cheques con CP" — cualquiera que use la app puede
-- dejar una idea/pedido, y se marca como realizada cuando se hace.

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
