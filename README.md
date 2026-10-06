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
   todo junto. Cada vendedor tiene un solo botón — **"Ver"** (o **"⚠ Revisar"** en rojo, si tiene
   algo sin resolver) — que abre un modal con **todos** sus pagos de ese mes (ya comisionados y
   pendientes, juntos). Ahí se puede elegir o cambiar el **Tipo** de cualquier fila (incluidas las
   ya resueltas — A = Factura, B = NOF, A/B = mixto, CHR = cheque rechazado) y la app calcula la
   comisión en vivo con el mismo criterio del pulido manual en Excel. Nada se guarda hasta tocar
   **"Guardar cambios"** (se activa solo con algo tocado) — y es reversible: volver a elegir
   "— Elegir —" en una fila ya resuelta la manda de nuevo a "sin comisión".
4. Al aprobar el grupo de un vendedor, su comisión de ese mes pasa a sumar en su cuenta corriente
   (pestaña **Vendedores**), donde se pueden registrar los pagos reales que se le hacen. Además, una
   vez aprobado, aparece un botón **"Marcar pagada"** (badge violeta) — es una marca visual
   independiente, no descuenta nada de la cuenta corriente ni requiere registrar el pago ahí; sirve
   solo para ver de un vistazo qué comisiones del mes ya se transfirieron. Se puede revertir.
5. **Reporte por Cliente** agrupa todo el detalle (de liquidaciones aprobadas, o de un mes puntual)
   por cliente.
6. **Excluidos** agrupa por cliente los pagos sin vendedor asignado o "Venta Propia" (con selector
   de período), en vez de mostrarse dentro del detalle de cada liquidación como antes — no aporta
   nada ahí (casi siempre vacío en el formato nuevo) y molestaba en la vista principal.
7. **Implementaciones** es un buzón de pedidos de mejora (mismo patrón que Hemkam-Laura y "Carga de
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
- **Resolver/reclasificar comisiones en la app** (11-sep-2026): `TIPO_DIVISOR` en `index.html`
  define el divisor sobre el Importe según el tipo elegido — `A: 1.21` (Factura, 21% IVA), `B: 1`
  (NOF, importe completo), `A/B: 1.105` (mixto, la mitad de 21% = 10,5%). CHR es comisión $0 fija,
  sin divisor. Validado contra datos reales de agosto 2026 (cierra exacto a la fracción de peso).
  Si algún día cambia el criterio de alguno de estos tipos, hay que actualizar esa constante — no
  está en ningún otro lado. El modal unificado (`verComisionVendedor`) permite tanto resolver una
  fila "sin comisión" (pasa a `liquidacion_detalle`) como reclasificar o **revertir** una ya
  resuelta (vuelve a `liquidacion_sin_comision`, reconstruyendo el motivo) — todo por
  `guardarCambiosComision`, que solo escribe las filas realmente tocadas (compara `current` vs
  `original` en `COMISION_CTX`).
- **Formato de 4 hojas leído por nombre de columna** (6-oct-2026): "Detalle - Comisión Calculada" y
  "Sin Comisión - Revisar" se mapean por encabezado (`ALIAS_DETALLE_V1` / `ALIAS_SIN_COMISION`), no
  por posición, porque la tarea programada fue cambiando el orden/cantidad de columnas (7 → 10 en
  "Sin Comisión", y la versión pulida a mano llegaba a 13). Si el encabezado no se reconoce, cae al
  mapeo posicional. Las filas TOTAL se ignoran en las tres hojas, y el preview avisa si hay pagos
  con importe $0 (señal de columnas corridas).
- **Aprobación recibo por recibo** (8-oct-2026): cada fila de `liquidacion_detalle` tiene `aprobado`
  (tildado). Dentro de **Ver** de un vendedor se tildan los recibos a aprobar; los tildados suman a
  la cuenta corriente, el Reporte por Cliente ("solo aprobadas") y los gráficos, y los no tildados
  quedan pendientes. El estado del vendedor sale de cuántos recibos tiene tildados (Pendiente /
  Parcial n/m / Aprobada) vía `estadoVisualGrupo()`; `liquidacion_vendedores.estado` se mantiene
  sincronizado con `sincronizarEstadoGrupo()` ('aprobada' solo si todos están tildados) y manda
  para "rechazada". Aprobar / Aprobar todo / Rechazar a nivel vendedor siguen existiendo como atajos.
  Si el vendedor está marcado "Pagada" no se pueden destildar recibos sin revertir esa marca. Una
  liquidación con recibos aprobados no se puede reemplazar al recargar el Excel.
  Requiere correr `sql/008_detalle_aprobacion.sql` (columnas + backfill de lo ya aprobado).
- **Medios de pago de cada recibo** (8-oct-2026): al tocar un número de recibo (en Ver de un
  vendedor, en el detalle de un período del estado de cuenta, y en el Reporte por Cliente) se abre
  una segunda ventana con cómo pagó el cliente: efectivo, transferencia (con N° de operación),
  cheques y echeqs (número, banco, fecha de cobro, importe). Los datos están en la tabla
  `recibos_pago` (`sql/007_recibos_pago.sql`), clave `(empresa, nro_pago)`, y salen de Odoo
  (`account.payment` + `l10n_latam.check`). Hoy están cargados Agosto y Septiembre 2026 (47
  recibos); los recibos cargados a mano (RC, del otro sistema) dicen "sin datos". Para meses nuevos
  hay que cargarlos: la idea es que la tarea programada agregue una hoja "Medios de pago" al Excel.
- **Aviso de versión nueva** (8-oct-2026): barra azul fija arriba cuando hay una versión publicada
  distinta de la cargada (`chequearVersionNueva`, compara el index.html cada 60 s y al volver a la
  pestaña).
- **Estado de cuenta por período** (8-oct-2026): en Vendedores → un vendedor, cada mes de
  "Liquidaciones aprobadas" abre los recibos aprobados que componen esa comisión.
- **Historial como pantalla inicial, con indicadores y gráficos** (7-oct-2026): al loguearse se
  abre Historial. Arriba tres indicadores (pendiente de aprobar / aprobado a pagar = aprobado −
  pagos registrados / pagado), después la tabla de liquidaciones y abajo un gráfico de barras con la
  comisión de cada mes, apilado por estado del vendedor (pendiente, aprobada, pagada, rechazada).
  Al tocar una barra, la dona de la derecha muestra el reparto por vendedor de ese mes (los de menos
  del 3% se agrupan como "Otros" en la dona; la lista muestra a todos con importe, % y estado).
  Usa Chart.js 4.4.1 desde cdnjs (`calcHistorialMeses`, `dibujarGraficosHistorial` en `index.html`).
  El indicador "aprobado a pagar" se pone en rojo si un vendedor cobró más de lo aprobado.
- **Pagos a vendedores editables** (7-oct-2026): en la pestaña Vendedores → detalle de un vendedor,
  cada pago registrado tiene **Editar** (fecha, importe, nota) y **Eliminar** (con confirmación); el
  saldo se recalcula solo. El importe del formulario acepta el formato argentino (`27.812` = 27812,
  `27.812,50`, `27,5`) vía `parseImporteAR()` y muestra "Se va a guardar: $ …" mientras se escribe,
  para detectar a tiempo un importe mal pegado.
- **Vendedores inactivos no se importan** (6-oct-2026): Laura Aguado se liquida aparte (35% sobre
  neto, fuera de esta app), así que está con `activo=false` en la tabla `vendedores`
  (ver `sql/006_laura_aguado_inactiva.sql`). `descartarVendedoresInactivos()` descarta al importar
  las filas de cualquier vendedor inactivo aunque la automatización las siga mandando, y el preview
  avisa cuántas ignoró. Para volver a liquidar a alguien acá alcanza con ponerlo `activo=true`.
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
