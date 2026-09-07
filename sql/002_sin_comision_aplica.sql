-- Migración: agrega la columna "aplica" a liquidacion_sin_comision.
-- Correr esto en el SQL Editor de Supabase si ya corriste schema.sql antes de esta fecha
-- (el Excel real trae una 8va columna "Aplica" en la hoja "Sin Comisión - Revisar" que no
-- estaba contemplada en el spec original — significado a confirmar con Diego).

alter table liquidacion_sin_comision add column if not exists aplica text;
