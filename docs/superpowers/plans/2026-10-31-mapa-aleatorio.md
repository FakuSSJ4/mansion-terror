# Plan: distribución del mapa aleatoria por partida

## Objetivo

Que en cada partida las salas queden en lugares distintos, con puertas con llave, refugios, escaleras y zonas de los asesinos coherentes con esa distribución, y que siempre se pueda ganar.

## Estado actual

Ya se sortea por partida (sin tocar la geometría): muebles de las esquinas, animal del pedestal, cabeza de trofeo, colores de paredes, pisos y alfombras, cuadros, y dónde se esconden llaves y pergaminos (`Mansion.rerollRound`, `Rules/Placement`).

No se sortea qué sala queda dónde. Eso está fijo en la construcción.

## Dónde está fijo hoy

| Qué | Dónde | Por qué molesta |
|---|---|---|
| Posición de cada sala en la grilla | `PLAN` en `Mansion.luau` | La geometría se arma una sola vez al iniciar el servidor |
| Qué pasillos hay | `LINKS` en `Mansion.luau` y `MapGraph.default` en `Rules/MapGraph.luau` | Están escritos dos veces, a mano |
| Qué puertas llevan llave | `LOCKED_LINKS`, `LOCKED_BY`, `Config.DoorKeys` | La puerta se llama como la sala de destino |
| Qué necesita cada sala para llegar | `Placement.Needs` | Escrito a mano, depende del orden actual |
| Refugios | `REFUGES` | Pegados a las piezas 1, 6 y 8 |
| Escalera imperial, escalera del sótano, trampilla | `STAIR`, `HATCH`, `buildStairs` | Fijas a las piezas 4, 5, 12 y el altillo |
| Zonas de los asesinos | `Config.Killers.gentleman.rooms` y `butcher.rooms` | Lista de nombres de sala |
| Hall, pieza 7, ala oeste | `GrandHall.luau` y `WEST_WING` | Construidos aparte, con medidas propias |
| Atajos de QA | `TOUR_STOPS` en `DebugTools.luau` | Coordenadas fijas |

## Dos caminos

### A. Barajar solo las salas intercambiables (recomendado como primera etapa)

Se barajan los *roles* de las salas comunes dentro de la cadena que ya existe, sin cambiar la forma del edificio. La planta baja (1, 2, 3) y el primer piso (8, 9, 10, 11) mantienen sus corredores, pero cada posición recibe una función al azar: living, comedor, sala de música, dormitorio, etc.

- Se mantiene: escaleras, trampilla, sótano, hall, ala oeste, refugios y las puertas con llave (que quedan en las mismas posiciones físicas).
- Cambia: el contenido y el nombre de cada sala. Los muebles especiales (mesa larga del comedor, piano, cama doble, chimenea) viajan con la función.
- Riesgo: bajo. No toca el grafo ni el reparto de llaves.
- Valor: moderado. Se sienten salas distintas, pero el recorrido es el mismo.

### B. Mapa procedural completo (segunda etapa)

El mapa pasa a ser datos y se genera cada partida.

1. **Un solo `MapDef`** (módulo compartido, sin APIs de Roblox) con: salas, a qué celda de la grilla va cada una, pasillos, puertas con llave, refugios, escaleras y zonas de asesinos.
2. **Generador** que arma un `MapDef` al azar con reglas: todas las salas conectadas, las llaves siempre alcanzables en orden, el sótano último, el altillo solo por la escalera.
3. **Todo lee del `MapDef`**: `MapGraph`, `Placement` (que calcula `Needs` en vez de tenerlo escrito), `Killer`, `Items` y `Mansion`.
4. **Reconstrucción por partida**: al reiniciar se destruye `world` y se vuelve a llamar a `Mansion.build`. Requiere que `Round`, `Killer`, `Items`, `Escape` y `DebugTools` reciban las referencias nuevas (hoy las guardan una sola vez).
5. **Pruebas** del generador con muchas semillas: conexo, ganable, sin llaves detrás de su propia puerta.

- Riesgo: alto. Toca casi todos los sistemas.
- Valor: alto. Es lo que hace Doors.

## Orden sugerido

1. `MapDef` como datos, con el mapa actual como único valor posible, y que todo lo lea de ahí. Es un refactor que no cambia el juego y se verifica con los tests actuales. **Este paso solo ya vale la pena.**
2. Camino A sobre ese `MapDef`.
3. Reconstrucción por partida (pasos 3 y 4 del camino B).
4. Generador y sus pruebas.
5. Variantes del generador: más pasillos, atajos con candado, salas extra.

## Decisiones que necesito de vos

- ¿Empezamos por el paso 1 (refactor sin cambios visibles)? Es el que más reduce el riesgo del resto.
- ¿Vale la pena reconstruir el edificio cada partida, o alcanza con sortearlo al abrir el servidor? Lo segundo es mucho más simple, pero el mapa se repite mientras el servidor siga vivo.
- ¿Las zonas de los asesinos deben seguir fijas (el del smoking arriba, el carnicero abajo) o también se sortean?

## Decisiones tomadas y avance

- Los asesinos NO se sortean: sus zonas quedan fijas (el del smoking arriba, el carnicero abajo). Cuando el mapa se sortee, esas zonas se definirán por piso y no por nombre de sala.
- Las salas enteras y los objetos de adentro SÍ se sortean.
- **Paso 1 hecho:** el mapa actual está en src/shared/Rules/MapDef.luau. MapGraph, Placement, Items, Killer y Mansion leen de ahí (pasillos, escaleras, trampilla, puertas con llave y refugios). Placement.Needs ya no está escrito a mano: sale de MapDef.needs(), y una prueba verifica que da lo mismo que la tabla anterior. Sin cambios visibles en el juego.
- **Hecho (reconstrucción por partida):** en cada partida se sortea en cuáles pasillos va cada una de las cuatro puertas con llave (`MapDef.rollLocks`). Las puertas se sacan y se vuelven a poner (`Mansion.rerollRound`), `Round` las reconecta y las llaves se reparten según las puertas de esa partida. Se descartan las distribuciones sin solución. Junto con los muebles, trofeos, colores, alfombras y cuadros que ya se sortean, cada partida es distinta.
- **Límite encontrado:** los pasillos y las piezas no se mueven. El edificio es una grilla de 2 por 3 donde las piezas forman una cadena, y los refugios ocupan la pared que haría falta para un pasillo alternativo. Para cambiar qué sala conecta con cuál hay que agrandar la grilla y mover los refugios.
- Pendiente: grilla más grande, refugios que se puedan mover, y el generador de pasillos.

## Pasillos alternativos (hecho)

- Se agregaron dos pasillos que cierran un ciclo en cada piso: pieza 1 con 4, y pieza 8 con 11. Todos los pasillos se construyen una vez.
- En cada partida se tapia con tablones un pasillo de cada ciclo (`MapDef.rollLayout`). Los ciclos quedan cortados, así que el mapa vuelve a ser un árbol, pero con otro recorrido: la cocina (y con ella el sótano) puede quedar a 3 pasos de la entrada o a 4, y las piezas de arriba cambian de orden.
- Las cuatro puertas con llave se sortean entre los pasillos que quedan abiertos (nueve posibles).
- Los refugios 1 y 3 pasaron a la pared norte, porque la pared sur ahora lleva un pasillo.
- Los asesinos siguen con sus zonas fijas por piso.
- Pruebas: la distribución siempre deja todo alcanzable, sin ciclos, y casi siempre permite repartir las llaves (las que no, se descartan en el juego).
- Sin hacer: agrandar la grilla con piezas nuevas. Mover piezas de lugar sigue pendiente.
