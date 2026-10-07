# 01 · Contrato real de `dbo.sp_debcred_empresa`

Fuente: `original/sp_debcred_empresa.sp` (los números de línea se refieren a ese archivo).
Motor: Sybase ASE / COBIS (sintaxis `db..tabla`, `save tran`, `cobis..sp_cerror`, `print '%1!'`).

## 1. Parámetros de entrada

| Parámetro | Tipo | Default | Línea | Uso real observado |
|---|---|---|---|---|
| `@s_ssn` | int | null | 4 | Se normaliza a 0 si es null (L266). Se pasa a `sp_ndc_ahcc` y `sp_grb_comision`. **No** se pasa a `sp_graba_tran_servicio` (va `null` literal). |
| `@s_user` | varchar(14) | null | 6 | Pasado a todas las llamadas transaccionales. |
| `@s_term` | varchar(30) | null | 8 | ⚠ **Contrato oculto**: si `@i_servicio = 'SPI'` se usa como **código de concepto** (`@w_concepto_bas`, varchar(5) → trunca) y luego se sobrescribe con `' '` (L282-284). Ver Q05. |
| `@s_srv` | varchar(30) | null | 10 | Pasado a las llamadas transaccionales. |
| `@s_ofi` | smallint | null | 12 | Se envía `0` literal a `sp_vi_ndc_automatica` y `sp_ndc_ahcc`, pero el valor real a `sp_graba_tran_servicio`, `sp_grb_mov_y_frmpgo` y `sp_grb_comision`. |
| `@i_aplcobis` | char(1) | 'N' | 14 | Define `@w_batch` (S→0, N→1, otro→NULL) (L176-178) y el modo de error en `lbl_error` (L2148). |
| `@i_sp_name` | varchar(32) | — | 16 | `@t_from` de `sp_cerror`; filtro del catálogo `ba_bloqueaNotificacionSAT`; pasado a `sp_grb_comision`. |
| `@i_orden` | int | — | 18 | Orden banco. Clave de búsquedas, `@i_alt`, `@i_orden_banco` y filtros de `bp_total_orden`. |
| `@i_orden_empresa` | int | — | 20 | Base de `@w_cadena` (referencia del débito). |
| `@i_fecha_proceso` | datetime | — | 22 | `@s_date` / `@i_fecha` / `@i_fch_contab`. |
| `@i_nem_emp` | char(15) | — | 24 | `@i_nem_ordenante`. |
| `@i_empresa` | int | — | 26 | Empresa ordenante. En el ramo de cuenta contable (tipo 9) se compara como **string** con `'1295'` (L1276). |
| `@i_producto` | smallint | — | 28 | |
| `@i_servicio` | varchar(10) | — | 30 | ⚠ **Se muta**: en devoluciones SPI (`tipo_afec='12'`) se reemplaza por el servicio de la orden original (L1374); puede quedar NULL. Ver Q14. |
| `@i_frm_pagcob` | char(3) | — | 32 | ⚠ Se muta a `@i_frm_pagcob_spi` para TRANSQUICK antes de la comisión (L1500-1502). |
| `@i_frm_pagcob_spi` | char(3) | null | 34 | ⚠ Es el valor que recibe `sp_ndc_ahcc.@i_frm_pagcob` (**no** `@i_frm_pagcob`) (L716). |
| `@i_canal` | char(3) | 'DIR' | 36 | |
| `@i_tipo_afec` | char(2) | '10' | 38 | |
| `@i_referencia` | varchar(100) | — | 40 | |
| `@i_mon_debito` | smallint | — | 42 | También se convierte a `char(2)` para `@w_moneda`. |
| `@i_pais_cta` | smallint | — | 44 | |
| `@i_cod_banco_cta` | smallint | — | 46 | |
| `@i_tipcta_emp` | smallint | — | 48 | Selecciona el ramo: 3/4/12, 9 o error 122001. |
| `@i_numcta_emp` | char(10) | — | 50 | |
| `@i_valor_ordenado` | money | — | 52 | |
| `@i_valor_debito` | money | — | 54 | ⚠ **Se muta** en dos lugares (L886 y L1278). Ver Q10 y Q17. |
| `@i_comision` | money | — | 56 | ⚠ Se puede trasladar a `@i_valor_comision` y quedar en 0 (L188-196). |
| `@i_valor_comision` | money | — | 58 | ⚠ Puede recibir `@i_comision` (L192). |
| `@i_tipo_referencia` | char(1) | — | 60 | Va a confcontable como `@i_referencia` y a `sp_grb_comision` como `@i_tipo_horario`. |
| `@i_tarjeta` | varchar(24) | null | 62 | |
| `@i_ref_prov` | varchar(24) | — | 64 | `@i_detalle` / `@i_detalle_ref` / `@i_referencia` (en tipo 9). |
| `@i_opcion` | char(2) | — | 66 | '01', '02', '03' seleccionan el filtro de `bp_total_orden` solo para los canales DIR/SFR/FR2/BTH/VEN. |
| `@i_tipo_pagcob` | char(1) | — | 68 | |
| `@i_localidad_orden` | smallint | — | 70 | |
| `@i_tipo_proceso` | char(1) | — | 72 | |
| `@i_frm_pagcob_deb` | char(3) | null | 74 | Si es null se toma `@i_frm_pagcob` **original** (L262, antes de cualquier mutación). |
| `@i_valor2_swift` | money | 0 | 76 | Segunda comisión TRANSWIFT y suma en el costo SMS. |
| `@i_secuencial` | int | 0 | 78 | Solo en lecturas de detalle TRANSWIFT y en `pa_sat_pnotificacion`. Las escrituras usan `0` literal. |
| `@i_cod_swift` | varchar(20) | null | 80 | Referencia TRANSWIFT y criterio CORPEI. ⚠ Se muta a `''` si es null en IMPADUAN (L460). |
| `@i_valor_tarifa` | money | null | 86 | ⚠ TRANSBIMO lo sobrescribe con `@i_valor_comision` (L1506-1508). |
| `@i_valor_comision_cue/_efe/_che`, `@i_valor_tarifa_efe/_che` | money | null | 88-96 | Pasados tal cual solo a la **primera** llamada de `sp_grb_comision`. |

## 2. Parámetros de salida

| Parámetro | Comportamiento real |
|---|---|
| `@o_error` | Se pone en 0 (L256). Puede ser **sobrescrito por `pa_sat_pnotificacion`** (L1080) y ese valor sobrevive hasta el `return 0` final (L2134). Ver Q13. |
| `@o_reg_a_proc` | **Nunca se asigna.** Conserva el valor que envió el llamador. |

## 3. Valores de retorno (return) y `@o_error`

| Situación | Línea | Transacción | `return` | `@o_error` |
|---|---|---|---|---|
| Éxito | 2130-2136 | commit | 0 | `isnull(@o_error,0)`: puede ser ≠0 (Q13) |
| Sin configuración contable | 382-394 | rollback si `@@trancount>0` (¡del llamador!) | `aplcobis='S'`: 120000 + `sp_cerror` · otro: 0 | otro: 120000 |
| Sin config. contable CORPEI | 532-544 | rollback de todo | igual al anterior | igual |
| Falla del débito o de la notificación (`@w_cod_errord≠0`) | 1480-1492 | rollback al savepoint, se graba el movimiento 'X', **commit** | `@w_cod_errord` (sin importar `aplcobis`) | `@w_cod_errord` |
| Tipo de cuenta no soportado | 1316 → 1480 | igual al anterior | 122001 | 122001 |
| Falla de `sp_grb_mov_y_frmpgo` | 1464-1476 | rollback de todo | `lbl_error` con 122002 | `lbl_error` |
| Falla de la 1ª comisión (REF44) | 1606-1700 | **rollback de todo** y se graba el movimiento de la comisión fuera de la transacción | `@w_cod_errord` (**puede ser 0**, ver Q19) | `@w_cod_errord` |
| Falla de la 2ª comisión TRANSWIFT | 1824-1836 | rollback de todo | `lbl_error` con 122003 o `@w_cod_errord` | `lbl_error` |
| `bp_total_orden` sin filas actualizadas | 2076-2090 | rollback de todo | `lbl_error` con 122004 | `lbl_error` |

`lbl_error` (L2140-2170): con `aplcobis='S'` ejecuta `cobis..sp_cerror @t_from=@i_sp_name, @i_num=@w_num_error` y retorna `@w_num_error`; con cualquier otro valor pone `@o_error=@w_num_error` y **retorna 0**.

## 4. Result sets emitidos al cliente

| Línea | Condición | Contenido |
|---|---|---|
| 882 | Ramo 3/4/12, débito OK, servicio ≠ PAGOPRV, `@w_serv_sms` encontrado, servicio ∈ (TRANSCLI, TARJCRED, COMEXT) | `select @i_comision, @i_valor_ordenado` (2 columnas sin nombre). Ver Q11. |
| 1726 | Inalcanzable (ver Q20) | `select @o_error` |
| — | `sp_cerror` y los sub-SP | Lo que emitan ellos |

## 5. Dependencias externas

**Procedimientos**: `db_biz_admempresa..sp_con_comision`, `db_biz_admempresa..sp_con_confcontable`,
`cob_virtuales..sp_vi_ndc_automatica`, `sp_ndc_ahcc`, `pa_sat_pnotificacion`, `cob_internet..sp_eventos`,
`db_biz_pagos..sp_graba_tran_servicio`, `sp_grb_mov_y_frmpgo`, `sp_grb_comision`, `cobis..sp_cerror`.

**Tablas leídas**: `cob_virtuales..vi_cuenta`, `db_biz_admempresa..ba_tabla/ba_catalogo`
(tablas lógicas `ad_concepto_contable`, `ad_servicios_sms`, `ad_cuentas_bce`, `ad_notificacion_basica`,
`ba_bloqueaNotificacionSAT`), `db_biz_pagos..bp_orden`, `db_biz_pagos..bp_detalle`, `bp_detalle` (sin
calificar: base actual), `db_sat_his..bp_orden_his`, `db_sat_his..bp_detalle_his`, `cob_cuentas..cc_ctacte`,
`cob_ahorros..ah_cuenta`.

**Tablas escritas**: `bp_total_orden` (base actual), `db_sat_his..bp_total_orden_his`. El resto de escrituras
ocurre dentro de los sub-SP.

**Configuración que cambia el comportamiento** (debe migrarse con los mismos datos): catálogos
`ad_concepto_contable` (NDCORPEI), `ad_servicios_sms`, `ad_cuentas_bce`, `ad_notificacion_basica`,
`ba_bloqueaNotificacionSAT`; configuración contable y de comisiones de `db_biz_admempresa`.
