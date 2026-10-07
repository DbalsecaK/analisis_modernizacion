# 03 · Quirks: comportamientos a preservar en `sp_debcred_empresa`

Son las conductas que una regla de negocio en prosa suele omitir o "corregir" sin querer.
**Decisión por defecto: PRESERVAR.** Cambiar cualquiera requiere una decisión firmada y un cambio aparte,
posterior a la migración. `VERIFICAR` = depende del motor o de un sub-SP; lo resuelve el golden master.

| ID | Líneas | Comportamiento real | Por qué se pierde fácil | Riesgo | Decisión |
|---|---|---|---|---|---|
| Q01 | 188-196 | El traslado `@i_comision → @i_valor_comision` solo ocurre si `@i_valor_comision = 0`; si es **NULL** no se traslada. | La regla dice "si viene comisión única, se separa" y omite el NULL. | Medio | Preservar |
| Q02 | 176-178 | `@i_aplcobis` distinto de 'S'/'N' deja `@w_batch = NULL`. | Un booleano en el destino no admite NULL. | Bajo | Preservar |
| Q03 | 242-244 | `@w_cantidad (int) = money / money`: truncamiento o redondeo. `VERIFICAR` en ASE. Luego `@w_comision_und` se pisa con `@w_val_por_tran`. | El destino usa decimal y redondea distinto. | Medio | Preservar, VERIFICAR |
| Q04 | 254 | `convert(char(2), @i_mon_debito)`: con moneda ≥ 100 el resultado es `*` o error. `VERIFICAR`. | | Bajo | Preservar |
| Q05 | 278-286 | **Contrato oculto**: con servicio SPI, `@s_term` trae el concepto contable (truncado a 5) y luego se pone en `' '`, que es lo que reciben todos los sub-SP como terminal. | Parece un parámetro de sesión. | **Alto** | Preservar; documentar en la interfaz nueva |
| Q06 | 382 | El error de confcontable es `return > 0`: un retorno negativo pasa como éxito. En CORPEI (L532) ni siquiera se revisa `@@error`. | La regla dice "si falla". | Medio | Preservar |
| Q07 | 2142-2144 | `lbl_error` hace `rollback tran` sin savepoint: si el llamador tenía una transacción abierta, **se la revierte** (también desde L392, antes del `begin tran`). | Los frameworks modernos anidan con savepoints. | **Alto** | Preservar, VERIFICAR a los llamadores |
| Q08 | 438 | `'COD:' + @i_cod_swift` con NULL: en ASE da `'COD:'`; en SQL Server/Oracle/Java puede dar NULL o `'COD:null'`. | Dependencia del motor. | Medio | Preservar `'COD:'` |
| Q09 | 484, 798, 826, 892, 1026 | Las asignaciones `select @v = col` con 0 filas **conservan** el valor previo; con N filas toman **la última** (orden no determinista). | Un ORM lanza excepción o toma la primera. | Medio | Preservar, VERIFICAR unicidad en datos |
| Q10 | 886 | Para TRANSCLI/TARJCRED/COMEXT con notificación configurada, **`@i_valor_debito = @i_valor_ordenado`**. Ese valor mutado llega a `sp_grb_mov_y_frmpgo.@i_valor_mov` (L1424). **Un catálogo de SMS cambia el monto grabado del movimiento.** | Está "dentro de la notificación". | **Crítico** | Preservar |
| Q11 | 882 | `select @i_comision, @i_valor_ordenado` suelto: devuelve un result set al cliente. | Parece un debug olvidado. | Medio | Preservar si algún llamador lee result sets; VERIFICAR |
| Q12 | 1248 | `@w_cod_errord = @w_return` **de la notificación**: si `sp_eventos` o `pa_sat_pnotificacion` fallan, el débito ya hecho se revierte (P9) y la orden queda 'X'. Si `patindex` no encuentra '-' (L798), el substring con longitud -1 es `VERIFICAR` en ASE. | La regla describe la notificación como "aviso". | **Crítico** | Preservar |
| Q13 | 1080, 2134 | `pa_sat_pnotificacion` escribe directamente `@o_error`; el SP puede terminar con `return 0` y `@o_error ≠ 0`. | | Alto | Preservar |
| Q14 | 1352-1374 | En devoluciones SPI, `@i_servicio` se reemplaza por el servicio original; si la orden no existe, queda **NULL** y el update de P16 no encuentra filas (pero `@w_act_totord='N'` evita el 122004). | | Alto | Preservar |
| Q15 | 984-986 | `convert(varchar(11), money)` trunca o falla con montos de 9 dígitos enteros o más. `VERIFICAR`. | | Medio | Preservar |
| Q16 | 1452-1454 | `@w_nombre_cuenta` nunca se asigna: el nombre de la cuenta y el del beneficiario se graban siempre NULL. | El to-be "lo llena bien". | Medio | Preservar NULL |
| Q17 | 1276-1278 | Caso fijo: empresa **1295** + SPI + cuenta contable → `@i_saldo = valor` y **`@i_valor_debito = 0`**, que también se graba en el movimiento (L1424). | Constante mágica. | **Alto** | Preservar |
| Q18 | 1264-1318 | En el ramo 9 y el ramo de error, `@w_cadena` y `@w_tran_ncnd` son NULL y se pasan así a `sp_grb_comision` y `sp_grb_mov_y_frmpgo`. | | Bajo | Preservar |
| Q19 | 1606-1700 | Si falla la comisión: **rollback de todo** (también del débito exitoso), se graba el movimiento de la comisión 'X' fuera de la transacción y `return @w_cod_errord`. Si el sub-SP retornó ≠0 pero `@o_error=0`, **el SP retorna 0 (éxito) con todo revertido**. 122003 se calcula y se descarta. | | **Crítico** | Preservar, VERIFICAR |
| Q20 | 1716-1730, 1844-1854 | Bloques inalcanzables: su condición ya está incluida en el `if` anterior. | Se reimplementan como si existieran. | Bajo | **No migrar** (documentado) |
| Q21 | 1824-1836 vs 1606 | La 2ª comisión TRANSWIFT usa `lbl_error` (con `sp_cerror` y retorno según `aplcobis`) y la 1ª usa REF44: hay dos políticas de error distintas para el mismo SP. | Se "unifica". | Alto | Preservar ambas |
| Q22 | 1884-2090 | Con un canal del grupo DIR y `@i_opcion` ∉ (01,02,03) no hay update; `@wRowdbBiz` conserva un valor **anterior** (de las lecturas TRANSWIFT o TRANSCLI) o NULL, y eso decide si se lanza el 122004. | Estado residual. | Alto | Preservar |
| Q23 | 1898 etc. | `bp_total_orden` y `bp_detalle` (L1028) sin base: dependen de la base en que se compila el SP. | | Medio | Fijar explícitamente en el destino |
| Q24 | 632, 686 vs 1286, 1400 | `@s_ofi` va como 0 a los débitos y con su valor real al resto. | Se "normaliza". | Bajo | Preservar |
| Q25 | 716-720 | `sp_ndc_ahcc` recibe `@i_frm_pagcob = @i_frm_pagcob_spi` (NULL salvo SPI/TRANSQUICK) y `@i_alterno_dos = @i_frm_pagcob`. | Parece un error de copia. | Alto | Preservar |
