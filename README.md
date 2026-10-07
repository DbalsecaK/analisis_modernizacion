# Análisis de modernización: preservar el comportamiento *as-is*

## El problema

Si se pasa directamente de **código legado → reglas de negocio → BDD**, el BDD
describe **lo que el negocio cree que el sistema debe hacer**, no **lo que el
código hace hoy**. En ese salto se pierden:

- efectos secundarios que nadie documentó (un `update` a una tabla histórica, un
  `select` suelto que devuelve un result set al cliente);
- mutaciones de parámetros que cambian valores aguas abajo;
- caminos de error con manejo transaccional inconsistente;
- comportamientos que dependen del motor (concatenación con `NULL`, asignación
  desde `select` sin filas, truncamientos);
- bugs de los que los consumidores ya dependen.

Una migración "tal cual" necesita una **especificación de caracterización**: una
descripción exhaustiva, trazable a número de línea, de lo que el código
**hace**, y no de lo que **debería hacer**.

## Dos capas que no se deben mezclar

| Capa | Pregunta que responde | Fuente | Uso en la migración |
|---|---|---|---|
| **1. Caracterización (as-is)** | ¿Qué hace el código hoy, línea por línea? | Solo el código y ejecuciones reales | **Criterio de aceptación**: el código nuevo debe ser equivalente |
| **2. Reglas de negocio (to-be)** | ¿Qué debería hacer? | Capa 1 + negocio | Documentación y backlog de mejoras **posteriores** |

Cualquier diferencia entre la capa 1 y la capa 2 **no se corrige en la
migración**: se registra como decisión explícita (columna `Decisión` del
catálogo de quirks) y se corrige después, en un cambio aparte.

## Los artefactos que se generan por cada SP

Ejemplo completo para `sp_debcred_empresa` en [`sp_debcred_empresa/`](sp_debcred_empresa/):

| # | Archivo | Qué contiene | Por qué evita perder código |
|---|---|---|---|
| 0 | `original/*.sp` | Fuente congelada, línea base de los números de línea | Todo lo demás referencia estas líneas |
| 1 | [`01_contrato.md`](sp_debcred_empresa/01_contrato.md) | Parámetros, defaults, salidas, códigos de retorno, result sets y contratos ocultos | La interfaz real, incluidos los usos "creativos" de parámetros |
| 2 | [`02_flujo_y_efectos.md`](sp_debcred_empresa/02_flujo_y_efectos.md) | Pasos ordenados, decisiones, **cada llamada con su mapeo exacto de parámetros**, cada DML y cada frontera transaccional | Es la "receta" que se reimplementa, sin interpretar |
| 3 | [`03_quirks.md`](sp_debcred_empresa/03_quirks.md) | Comportamientos raros, bugs, código muerto y dependencias del motor | Es exactamente lo que el BDD de reglas de negocio omite |
| 4 | [`04_caracterizacion.feature`](sp_debcred_empresa/04_caracterizacion.feature) | Gherkin *as-is* etiquetado con líneas y quirks | BDD ejecutable que describe lo que **hace**, no lo que **debería** hacer |
| 5 | [`05_trazabilidad.csv`](sp_debcred_empresa/05_trazabilidad.csv) | Cada rango de líneas → paso, quirk y escenario que lo cubren | **Control de completitud**: ninguna línea ejecutable queda sin dueño |
| 6 | [`06_golden_master.md`](sp_debcred_empresa/06_golden_master.md) | Cómo capturar ejecuciones reales con SP espía para comparar old y new | Convierte la especificación en una prueba de equivalencia automática |

## Flujo de trabajo recomendado

1. **Congelar** la fuente (`original/`).
2. **Contrato**: extraer la interfaz real (1).
3. **Flujo y efectos**: recorrer el SP de arriba abajo y anotar cada sentencia
   con efecto observable (2). Regla: si una sentencia cambia una variable que
   luego llega a una llamada, a un DML o a la salida, va al documento.
4. **Quirks**: todo lo que sorprenda se anota con una decisión, que por defecto
   es "preservar" (3).
5. **Trazabilidad**: cubrir el 100% de las líneas ejecutables (5). Una línea sin
   fila en el CSV es código potencialmente perdido.
6. **Caracterización**: un escenario por camino y por quirk (4).
7. **Golden master**: ejecutar el SP original con SP espía y guardar las salidas
   como resultado esperado (6). El código migrado debe producir exactamente lo
   mismo.
8. Recién entonces, **reglas de negocio**: se derivan de 2 y 3 y alimentan el
   backlog *to-be*.

## Prompt sugerido para generar estos artefactos con un LLM

> Analiza el SP adjunto. **No infieras intención de negocio.** Describe
> únicamente lo que el código hace, citando números de línea. Genera:
> (1) contrato: parámetros, defaults, outputs, return codes, result sets y
> parámetros reutilizados para otros fines;
> (2) flujo ordenado: cada `exec` con el mapeo completo parámetro→valor, cada
> DML con su filtro, cada `begin/commit/rollback/save tran`, y cada mutación de
> parámetros de entrada;
> (3) quirks: bugs, código muerto o inalcanzable, comportamientos dependientes
> del motor (NULL, truncamientos, asignación con 0 o N filas), result sets
> sueltos y manejo de errores inconsistente;
> (4) escenarios Gherkin *as-is* etiquetados `@L<ini>-<fin>`;
> (5) una matriz que cubra todas las líneas ejecutables.
> Si algo es ambiguo, márcalo como `VERIFICAR` y no lo resuelvas por intuición.
