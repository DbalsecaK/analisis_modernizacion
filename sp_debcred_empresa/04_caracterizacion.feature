# language: es
# Caracterización AS-IS de sp_debcred_empresa.
# Describe lo que el código HACE hoy (incluidos bugs), no lo que debería hacer.
# Cada escenario se etiqueta con las líneas y quirks que cubre; los "Entonces" se verifican
# con el golden master (SP espía), no con supuestos.

@as-is @sp_debcred_empresa
Característica: Débito a empresa con comisión y notificación (comportamiento actual)

  Antecedentes:
    Dado que los sub-SP están reemplazados por espías que registran parámetros y devuelven lo configurado

  @L320-394 @Q06 @P4
  Esquema del escenario: Error de configuración contable antes de abrir la transacción
    Dado que sp_con_confcontable retorna <ret>
    Y @i_aplcobis = "<aplcobis>"
    Cuando se ejecuta sp_debcred_empresa
    Entonces el return es <return> y @o_error es <o_error>
    Y no se invoca ningún SP de débito

    Ejemplos:
      | ret | aplcobis | return | o_error |
      | 1   | S        | 120000 | 0       |
      | 1   | N        | 0      | 120000  |

  @L382 @Q06
  Escenario: Un retorno negativo de sp_con_confcontable no se trata como error
    Dado que sp_con_confcontable retorna -1
    Cuando se ejecuta sp_debcred_empresa
    Entonces se abre la transacción y se invoca el SP de débito

  @L278-286 @Q05
  Escenario: Con SPI, @s_term transporta el concepto contable
    Dado @i_servicio = "SPI" y @s_term = "77"
    Cuando se ejecuta sp_debcred_empresa
    Entonces sp_con_confcontable recibe @i_concepto = "77"
    Y sp_ndc_ahcc recibe @s_term = " "

  @L676-730 @Q25
  Escenario: sp_ndc_ahcc recibe la forma de pago SPI y la forma de pago normal como alterna
    Dado @i_tipcta_emp = 4, @i_frm_pagcob = "CUE" y @i_frm_pagcob_spi nulo
    Cuando se ejecuta sp_debcred_empresa
    Entonces sp_ndc_ahcc recibe @i_frm_pagcob nulo y @i_alterno_dos = "CUE"

  @L628-666 @P6.4
  Escenario: Cuenta virtual usa sp_vi_ndc_automatica con canal fijo SAT
    Dado @i_tipcta_emp = 12
    Cuando se ejecuta sp_debcred_empresa
    Entonces sp_vi_ndc_automatica recibe @i_canal = "SAT", @s_ofi = 0 e @i_alt = @i_orden

  @L878-886 @L1424 @Q10 @Q11
  Escenario: TRANSCLI con SMS configurado graba el valor ordenado como valor del movimiento
    Dado @i_servicio = "TRANSCLI", @i_valor_debito = 100 y @i_valor_ordenado = 120
    Y existe en ad_servicios_sms un registro activo para TRANSCLI en el canal SAT
    Cuando se ejecuta sp_debcred_empresa
    Entonces se emite un result set con (@i_comision, 120)
    Y sp_grb_mov_y_frmpgo recibe @i_valor_mov = 120

  @L878-886 @Q10
  Escenario: TRANSCLI sin SMS configurado graba el valor del débito
    Dado @i_servicio = "TRANSCLI", @i_valor_debito = 100 y @i_valor_ordenado = 120
    Y no existe configuración SMS para TRANSCLI
    Cuando se ejecuta sp_debcred_empresa
    Entonces sp_grb_mov_y_frmpgo recibe @i_valor_mov = 100

  @L1210-1248 @L1332-1342 @L1480-1492 @Q12
  Escenario: Si la notificación falla, se revierte el débito exitoso
    Dado sp_ndc_ahcc retorna 0 y cob_internet..sp_eventos retorna 50001
    Cuando se ejecuta sp_debcred_empresa
    Entonces se hace rollback al savepoint "sp_debito_empresa"
    Y sp_grb_mov_y_frmpgo recibe @i_est_proceso = "X" e @i_cod_error = 50001
    Y el return es 50001

  @L1052-1082 @L2134 @Q13
  Escenario: pa_sat_pnotificacion puede dejar @o_error distinto de cero con return 0
    Dado ad_notificacion_basica configura "B" para el servicio
    Y pa_sat_pnotificacion retorna 0 con @o_error = 7
    Cuando se ejecuta sp_debcred_empresa sin otros errores
    Entonces el return es 0 y @o_error es 7

  @L1276-1298 @Q17
  Escenario: Empresa 1295 con SPI sobre cuenta contable
    Dado @i_empresa = 1295, @i_servicio = "SPI", @i_tipcta_emp = 9 e @i_valor_debito = 300
    Cuando se ejecuta sp_debcred_empresa
    Entonces sp_graba_tran_servicio recibe @i_saldo = 300 e @i_valor = 0
    Y sp_grb_mov_y_frmpgo recibe @i_valor_mov = 0

  @L1316 @L1480-1492
  Escenario: Tipo de cuenta no soportado
    Dado @i_tipcta_emp = 5
    Cuando se ejecuta sp_debcred_empresa
    Entonces no se invoca ningún SP de débito
    Y sp_grb_mov_y_frmpgo recibe @i_est_proceso = "X"
    Y la transacción se confirma y el return es 122001

  @L1606-1700 @Q19
  Esquema del escenario: Falla de la comisión revierte todo, incluido el débito
    Dado sp_ndc_ahcc retorna 0 e @i_valor_comision = 5
    Y sp_grb_comision retorna <ret> con @o_error = <oerr>
    Cuando se ejecuta sp_debcred_empresa
    Entonces se hace rollback de toda la transacción
    Y sp_grb_mov_y_frmpgo se invoca fuera de la transacción con @i_valor_mov = 5 e @i_referencia = "COBRO DE COMISION"
    Y el return es <return>

    Ejemplos:
      | ret | oerr | return |
      | 0   | 900  | 900    |
      | 1   | 0    | 0      |

  @L1742-1836 @Q21
  Escenario: La falla de la segunda comisión TRANSWIFT usa lbl_error
    Dado @i_servicio = "TRANSWIFT", @i_valor2_swift = 10 e @i_aplcobis = "N"
    Y la segunda llamada a sp_grb_comision retorna 1 con @o_error = 0
    Cuando se ejecuta sp_debcred_empresa
    Entonces el return es 0 y @o_error es 122003

  @L1348-1380 @Q14
  Escenario: Devolución SPI cambia el servicio con el que se graba
    Dado @i_servicio = "SPI", @i_tipo_afec = "12" y la orden original es de "ROLPAGO"
    Cuando se ejecuta sp_debcred_empresa
    Entonces sp_grb_mov_y_frmpgo recibe @i_servicio = "ROLPAGO"
    Y no se lanza el 122004 aunque bp_total_orden no tenga filas

  @L1876-2090 @Q22
  Esquema del escenario: Filtro de bp_total_orden según canal y opción
    Dado @i_canal = "<canal>" e @i_opcion = "<opcion>"
    Cuando se ejecuta sp_debcred_empresa
    Entonces el update filtra te_frm_pagcob en <filtro>

    Ejemplos:
      | canal | opcion | filtro                        |
      | DIR   | 01     | (@i_frm_pagcob_deb)           |
      | VEN   | 02     | ('CUE','EFE','CHL')           |
      | BTH   | 03     | ('CUE','EFE','CHE')           |
      | DIR   | 99     | ninguno: no hay update        |
      | BNK   | 01     | ('COB','TRC','CTB','CPD','TPD') |

  @L1904-1924 @L2076-2090
  Escenario: Fallback a la tabla histórica y error 122004
    Dado que la orden no está en bp_total_orden ni en bp_total_orden_his
    Y @i_servicio = "ROLPAGO", @i_canal = "BNK" e @i_aplcobis = "S"
    Cuando se ejecuta sp_debcred_empresa
    Entonces se hace rollback de todo, se invoca cobis..sp_cerror con 122004 y el return es 122004
