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
   carga los 17 vendedores con su % vigente. Si la base ya existía antes del 7-sep-2026, correr
   también, en orden, [`sql/002_sin_comision_aplica.sql`](sql/002_sin_comision_aplica.sql),
   [`sql/003_implementaciones.sql`](sql/003_implementaciones.sql),
   [`sql/004_liquidacion_vendedores.sql`](sql/004_liquidacion_vendedores.sql) y
   [`sql/005_liquidacion_vendedores_pagado.sql`](sql/005_liquidacion_vendedores_pagado.sql).
3. En **Project Settings → API**, copiar la **Project URL** y la clave **anon/public**.
4. Abrir `index.html` y reemplazar al principio del `<script>`:
   ```js
   const SUPABASE_URL='https://TU-PROYECTO.supabase.co';
   const SUPABASE_KEY='TU-ANON-KEY';
   ```
5. Las contraseñas de `USERS` (usuarios `diego` y `gonzalo`) están en `admin` a pedido — cambiarlas
   por algo más fuerte antes de publicar la app en cualquier lugar accesible desde internet.

No hay build ni dependencias — es un único `index.html` que se puede abrir directo o publicar en
cualquier hosting estático (Vercel, Netlify, GitHub Pages).

## Cómo probar localmente

No hay servidor de dev en el proyecto. Para servir el `index.html`:

```bash
python -m http.server --directory "C:\Claude\Projects\Comisiones-Vendedores" 8765
```

(el `.claude/launch.json` ya deja esto configurado para usar con `preview_start` en Claude Code).

## Flujo mensual

1. Bajar el Excel del chat de la tarea programada de Claude, y pulirlo a mano (resolver los casos
   que la automatización no puede clasificar sola — cheques rechazados, saldos de migración, etc.)
   dejando una sola hoja **"Detalle"** con todo: `Vendedor | Empresa | Fecha | Cliente | N° de Pago |
   Importe | Factura/NOF | Tasa | Donde se liquida | A o B | Comision`. Una fila sin nada en
   "Comision" (en blanco) significa "todavía sin definir" — esas van solas a "Sin Comisión -
   Revisar" en la app. Un 0 en "Comision" es un valor real (ej. un cheque rechazado) y sí se
   importa a Detalle, visible con $0. (El formato viejo de 4 hojas también se sigue soportando,
   por compatibilidad — ver notas más abajo.)
2. En la app, pestaña **Cargar Liquidación** → elegir mes/año (se autodetecta según las fechas del
   archivo) → subir el Excel → revisar el preview → **Confirmar y guardar**.
3. En **Historial**, abrir la liquidación cargada. La aprobación es **por vendedor, no por mes
   completo**: cada vendedor con actividad ese mes tiene su propio Aprobar/Rechazar (con motivo) en
   la tabla de Resumen, así un caso puntual (ej. un cheque rechazado a confirmar) no frena a los
   demás. Hay un atajo "Aprobar todos los pendientes de un saque" para el caso común de aprobar
   todo junto. El botón **"Ver"** de cada fila abre el detalle de los pagos que forman esa
   comisión puntual (filtrado por vendedor, en vez de una única tabla plana con los 17 mezclados).
   Si el vendedor tiene pagos sin comisión definida todavía, aparece además **"⚠ Revisar"** (rojo),
   que abre esos pagos filtrados por vendedor con un aviso explicando que no suman al total hasta
   que se resuelvan en el Excel.
4. Al aprobar el grupo de un vendedor, su comisión de ese mes pasa a sumar en su cuenta corriente
   (pestaña **Vendedores**), donde se pueden registrar los pagos reales que se le hacen. Además, una
   vez aprobado, aparece un botón **"Marcar pagada"** (badge violeta) — es una marca visual
   independiente, no descuenta nada de la cuenta corriente ni requiere registrar el pago ahí; sirve
   solo para ver de un vistazo qué comisiones del mes ya se transfirieron. Se puede revertir.
5. **Reporte por Cliente** agrupa todo el detalle (de liquidaciones aprobadas, o de un mes puntual)
   por cliente.
6. **Implementaciones** es un buzón de pedidos de mejora (mismo patrón que Hemkam-Laura y "Carga de
   cheques con CP"): cualquiera anota una idea, queda en "Pendientes", y se marca "Realizado" cuando
   se hace.

## Notas de diseño / pendientes conocidos

- **Dos formatos de Excel soportados** (`parseWorkbook` en `index.html` detecta cuál es): si
  encuentra una hoja separada de "Sin Comisión"/"Excluidos" usa el parser viejo (`COLS_DETALLE_V1`,
  4 hojas); si no, asume el formato nuevo de una sola hoja "Detalle" (`COLS_DETALLE_V2`,
  11-sep-2026 en adelante). El parseo es **posicional** en ambos casos (columnas por orden, no por
  texto exacto de encabezado) — si Diego cambia el orden de columnas de su planilla pulida, hay que
  actualizar `COLS_DETALLE_V2`. La fila de encabezado se ubica buscando el texto ("Vendedor" o
  "Cliente" según la hoja), no por posición fija, así no importa si hay una fila de título arriba.
- **"Ruben" en el formato nuevo**: la planilla pulida ya no distingue "Ruben (7,5%)" de
  "Ruben (10%)" por nombre — solo dice "Ruben", y la tasa real va en la columna Tasa de cada fila.
  `resolveVendorName()` matchea automáticamente contra los dos vendedores existentes según esa tasa
  (con ±0.01 de tolerancia). Si alguna vez aparece una fila de Ruben con una tasa que no sea 7.5%
  ni 10%, va a quedar como "Ruben" sin resolver — el preview de carga lo marca en rojo.
- La columna **"% Comisión"** del Excel real viene como fracción (0.05 = 5%), no como "5" —
  `normalizePct()` en `index.html` lo detecta y convierte (cualquier valor ≤1 se multiplica ×100).
- La hoja "Sin Comisión - Revisar" real trae una columna extra, **"Aplica"** (valores como 50/50,
  RM, FC, CHR, N/C, ?), que son anotaciones manuales de Diego para su propio seguimiento — se
  guarda y se muestra tal cual, sin ninguna lógica automática atada a esos códigos.
- **Aprobación por vendedor** (7-sep-2026): la tabla `liquidaciones` conserva sus columnas
  `estado`/`revisado_por`/`revisado_at`/`motivo_rechazo` por compatibilidad, pero ya no se usan —
  la app aprueba/rechaza por vendedor en la tabla `liquidacion_vendedores` (una fila por
  `(liquidacion_id, vendedor_nombre)`). La cuenta corriente y el Reporte por Cliente filtran por
  esta tabla, no por el estado de la liquidación completa.
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
