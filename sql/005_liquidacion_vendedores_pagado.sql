-- Marca visual independiente de "pagada" para cada vendedor dentro de una
-- liquidación (no toca la cuenta corriente / pagos_vendedor — es solo un
-- check manual para saber de un vistazo qué comisiones ya se transfirieron).

alter table liquidacion_vendedores add column if not exists pagado boolean not null default false;
alter table liquidacion_vendedores add column if not exists pagado_por text;
alter table liquidacion_vendedores add column if not exists pagado_at timestamptz;
