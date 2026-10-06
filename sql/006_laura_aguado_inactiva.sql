-- Laura Aguado se liquida aparte (35% sobre neto, fuera de esta app): no debe figurar ni
-- importarse. activo=false la saca de la tabla de Resumen y de Vendedores, y la carga de Excel
-- ignora las filas de cualquier vendedor inactivo.
update vendedores set activo = false where nombre_mostrar = 'Laura Aguado';
