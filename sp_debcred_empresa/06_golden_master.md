# 06 · Golden master con cobertura de ramas del *as-is*

Objetivo: demostrar con ejecuciones reales, y no con prosa, que (a) el destino hace lo mismo que el
original y (b) **cada rama del original fue ejercitada por algún caso**. Lo segundo es lo que garantiza
que no se perdió código: una rama sin caso es una rama que el destino podría omitir sin que nadie lo note.

## 1. Lo que se compara por caso

| Observable | Cómo se captura en el original (Sybase) |
|---|---|
| `return` y parámetros `OUT` (`@o_error`, `@o_reg_a_proc`) | Harness que ejecuta el SP |
| Result sets (p. ej. L882) | Harness: se guardan todos, en orden |
| Llamadas a sub-SP con **todos** sus parámetros y su orden | **SP espía** con la misma firma que inserta en `gm_llamada` y devuelve lo configurado para el caso |
| Estado de las tablas escritas (`bp_total_orden`, `_his`) y frontera transaccional | Snapshot antes y después; `@@trancount` registrado por el espía |
| **Ramas ejecutadas** | Copia instrumentada del SP (sección 3) |

```sql
create table gm_llamada (caso varchar(30), orden int identity, sp varchar(64),
                         trancount int, params varchar(2000), fecha datetime default getdate())
create table gm_rama    (caso varchar(30), rama varchar(20), hits int)
create table gm_config  (caso varchar(30), sp varchar(64), llamada int, ret int, out1 varchar(100))
```

Ejemplo de espía (uno por dependencia, con la firma exacta del real):
```sql
create procedure sp_grb_comision ( /* misma firma que el real */ ... , @o_error int output ) as
  insert gm_llamada (caso, sp, trancount, params)
  values (@@gm_caso, 'sp_grb_comision', @@trancount,
          'valor_comision=' + convert(varchar, @i_valor_comision) + '|referencia=' + @i_referencia + '|...')
  select @o_error = convert(int, out1) from gm_config where caso=@@gm_caso and sp='sp_grb_comision'
  return (select ret from gm_config where caso=@@gm_caso and sp='sp_grb_comision')
```
(`@@gm_caso` es ilustrativo: en ASE se suele pasar por una tabla de contexto `gm_ctx` con una sola fila.)

## 2. Matriz mínima de casos (una fila por rama y quirk)

Se deriva de `05_trazabilidad.csv` (columna `paso`) y de `03_quirks.md`. Cada rango `ejecutable`
necesita al menos un caso que lo ejecute; cada `if` necesita un caso con la condición verdadera y otro
con la condición falsa. Para este SP son unas 45 ramas. Los escenarios de `04_caracterizacion.feature`
son la semilla; el informe de la sección 3 dice cuáles faltan.

## 3. Cobertura de ramas sobre el original (determinista)

1. Se genera una copia `sp_debcred_empresa_gm` y se inserta una sonda al inicio de **cada bloque**
   (después de cada `begin`, cada `else` y cada etiqueta):
   `insert gm_rama values (@caso, 'L0628', 1)` (el id es la línea del original).
2. Se ejecutan todos los casos.
3. El informe cruza `gm_rama` con la lista de sondas:
   - **ramas no ejecutadas** → se listan como "no probado" y bloquean el veredicto o pasan a decisión del revisor;
   - ramas **inalcanzables** conocidas (Q20) → se excluyen explícitamente, no en silencio.
4. Se repite hasta que la cobertura de ramas ejecutables sea del 100% o cada hueco tenga una decisión firmada.

La inserción de sondas se puede automatizar: basta un parser que reconozca `begin`/`end`/`else`/`if`
sin `begin` y `lbl_*:` en T-SQL de Sybase; las sentencias no se tocan, así que el comportamiento no cambia.

## 4. Datos que también son lógica

Los catálogos `ba_catalogo` citados en `01_contrato.md §5` deciden ramas (Q10, Q12, Q22). El golden
master debe correr con **una copia de los catálogos de producción**, más casos que fuercen cada valor
relevante (configurado / no configurado / duplicado).
