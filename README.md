# Comisiones de Vendedores — Magontex / Instatex

App para gestionar la liquidación mensual de comisiones a vendedores: subir el Excel que produce la
tarea programada (Odoo), revisarlo, aprobarlo o rechazarlo, y llevar la cuenta corriente de cada
vendedor (comisión aprobada − pagos registrados).

La lógica de **cálculo** de la comisión (qué pagos de Odoo corresponden a qué vendedor, base
comisionable, etc.) no vive acá — sigue corriendo como tarea programada aparte. Esta app solo
gestiona el resultado de ese cálculo: carga, aprobación y pagos.

## Puesta en marcha

1. **Crear un proyecto nuevo en [supabase.com](https://supabase.com)** (gratis).
2. En el SQL Editor del proyecto, correr [`sql/schema.sql`](sql/schema.sql) — crea las tablas y
   carga los 17 vendedores con su % vigente.
3. En **Project Settings → API**, copiar la **Project URL** y la clave **anon/public**.
4. Abrir `index.html` y reemplazar al principio del `<script>`:
   ```js
   const SUPABASE_URL='https://TU-PROYECTO.supabase.co';
   const SUPABASE_KEY='TU-ANON-KEY';
   ```
5. Cambiar las contraseñas de `USERS` (usuarios `diego` y `jefe`) por algo real, antes de publicar
   la app en ningún lado accesible.

No hay build ni dependencias — es un único `index.html` que se puede abrir directo o publicar en
cualquier hosting estático (Vercel, Netlify, GitHub Pages).

## Cómo probar localmente

No hay servidor de dev en el proyecto. Para servir el `index.html`:

```bash
python -m http.server --directory "C:\Claude\Projects\Comisiones-Vendedores" 8765
```

(el `.claude/launch.json` ya deja esto configurado para usar con `preview_start` en Claude Code).

## Flujo mensual

1. Bajar el Excel del chat de la tarea programada (4 hojas: Resumen, Detalle - Comisión Calculada,
   Sin Comisión - Revisar, Excluidos).
2. En la app, pestaña **Cargar Liquidación** → elegir mes/año (se autodetecta según las fechas del
   archivo) → subir el Excel → revisar el preview → **Confirmar y guardar**.
3. En **Historial**, abrir la liquidación cargada y **Aprobar** o **Rechazar** (con motivo).
4. Al aprobar, la comisión de cada vendedor pasa a sumar en su cuenta corriente (pestaña
   **Vendedores**), donde se pueden registrar los pagos reales que se le hacen.
5. **Reporte por Cliente** agrupa todo el detalle (de liquidaciones aprobadas, o de un mes puntual)
   por cliente.

## Notas de diseño / pendientes conocidos

- El parseo del Excel es **posicional** (toma las columnas por orden, no por el texto exacto del
  encabezado) porque el archivo lo genera siempre el mismo proceso automatizado. Si el orden de
  columnas de esa tarea programada cambia alguna vez, hay que actualizar `COLS_DETALLE`,
  `COLS_SIN_COMISION` y `COLS_EXCLUIDOS` en `index.html`.
- Si el Excel trae un vendedor cuyo nombre no matchea ningún `nombre_mostrar` de la tabla
  `vendedores`, el preview de carga lo marca en rojo. Igual se puede confirmar la carga, pero esa
  comisión no va a sumar en la cuenta corriente de nadie hasta que el nombre coincida (ajustar a
  mano en la tabla `vendedores` de Supabase, o corregir el nombre en el Excel y volver a subir si
  la liquidación todavía está en estado "pendiente").
- El tema de **cheques rechazados** (Odoo no revierte la conciliación cuando un cheque rebota) sigue
  sin resolverse — es un problema de la tarea de cálculo en Odoo, no de esta app. Si en el futuro
  se detecta un pago que en realidad rebotó, hoy la única forma de corregirlo acá es rechazar la
  liquidación completa y volver a cargarla con el Excel corregido (o, si ya estaba aprobada, ajustar
  a mano en Supabase).
- Login propio hardcodeado en el JS (`USERS`), sin autenticación real de Supabase — mismo patrón
  que la app de Hemkam-Laura. Alcanza para 2 usuarios, no lo uses para un dato más sensible sin
  revisar esto.
