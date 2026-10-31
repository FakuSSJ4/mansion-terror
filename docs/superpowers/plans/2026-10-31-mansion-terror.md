# Mansión de terror: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Juego cooperativo de terror para Roblox: escapar de una mansión juntando 6 llaves y 8 libros mientras un asesino persigue a los jugadores.

**Architecture:** Servidor autoritativo con sistemas en `src/server/Systems`, controladores de cliente en `src/client/Controllers` y datos compartidos en `src/shared`. La lógica de reglas vive en módulos puros, sin APIs de Roblox, probados con Lune; los sistemas solo conectan esas reglas con el mundo.

**Tech Stack:** Luau `--!strict`, Rojo, Rokit, Selene, StyLua, Lune (pruebas).

**Spec:** `docs/superpowers/specs/2026-10-31-mansion-terror-design.md`

## Global Constraints

- Todo valor de balance sale de `src/shared/Config.luau`; ningún sistema tiene números de balance propios.
- Módulos en `src/shared/Rules` sin `game`, `workspace` ni `script`: reciben todo por parámetro, incluido el `Random`.
- El cliente nunca decide vida, objetos, puertas ni estado de partida.
- Textos visibles en español.
- `StreamingEnabled = false` en `default.project.json`.
- Sin DataStore.

## Review Focus

- Jugador que se desconecta siendo el objetivo del asesino: elige otro objetivo o patrulla, sin errores.
- Dos jugadores agarran el mismo objeto a la vez: solo uno lo obtiene y el progreso cuenta una vez.
- Jugador que muere durante la persecución: el asesino no sigue yendo a su cadáver ni al hall por él.
- Reinicio de partida con jugadores adentro: no quedan conexiones, objetos ni puertas de la ronda anterior.
- Disparo de taser durante el aturdimiento o con el asesino en inmunidad: no gasta la carga ni extiende el efecto.

---

### Task 1: Base del proyecto y reglas de mapa y progreso

**Files:**
- Create: `rokit.toml`, `selene.toml`, `stylua.toml`, `.gitignore`, `default.project.json`, `README.md` (copiados y adaptados de `spore-celula`)
- Create: `src/shared/Config.luau`, `src/shared/Rules/MapGraph.luau`, `src/shared/Rules/Progress.luau`
- Test: `tests/run.luau`, `tests/MapGraph.luau`, `tests/Progress.luau`

**Interfaces:**
- Produces: `Config` con todos los valores del spec.
- Produces: `MapGraph.default(): Graph`, `MapGraph.distance(g: Graph, a: string, b: string): number`, `MapGraph.isRefuge(g: Graph, id: string): boolean`. Ids: `"hall"`, `"room1"` a `"room12"`, `"exit"`, `"refuge1"` a `"refuge3"`.
- Produces: `Progress.new(): State`, `Progress.addKey(s, n: number): boolean`, `Progress.addBook(s, id: string): boolean`, `Progress.isDoorOpen(s, room: number): boolean`, `Progress.isExitOpen(s): boolean`. Los `add` devuelven `false` si ya se había contado.

- [ ] **Step 1:** Inicializar git en `mansion-terror`, agregar la base y `lune` a `rokit.toml`. Run: `rokit install`. Expected: `lune --version` imprime versión.
- [ ] **Step 2: Escribir las pruebas que fallan**

```lua
-- MapGraph
assert(MapGraph.distance(g, "hall", "room4") == 4)
assert(MapGraph.distance(g, "room2", "refuge1") == 1)
assert(MapGraph.distance(g, "room9", "refuge3") == 1)
assert(MapGraph.isRefuge(g, "refuge2") and not MapGraph.isRefuge(g, "room5"))
-- Progress
assert(Progress.isDoorOpen(s, 1))          -- hall a pieza 1, sin llave
assert(not Progress.isDoorOpen(s, 2))
assert(Progress.addKey(s, 1) and not Progress.addKey(s, 1))
assert(Progress.isDoorOpen(s, 2))
-- con 7 libros, false; con el 8vo, true
assert(Progress.isExitOpen(s8))
```

- [ ] **Step 3:** Run: `lune run tests/run`. Expected: FAIL por módulos inexistentes.
- [ ] **Step 4:** Implementar `Config`, `MapGraph` (BFS sobre lista de adyacencia) y `Progress`.
- [ ] **Step 5:** Run: `lune run tests/run`. Expected: PASS.
- [ ] **Step 6:** Commit `feat: base del proyecto y reglas de mapa y progreso`.

### Task 2: Reglas de vida, objetos y asesino

**Files:**
- Create: `src/shared/Rules/Vitals.luau`, `src/shared/Rules/Taser.luau`, `src/shared/Rules/KillerBrain.luau`
- Test: `tests/Vitals.luau`, `tests/Taser.luau`, `tests/KillerBrain.luau`

**Interfaces:**
- Consumes: `Config`.
- Produces: `Vitals.damage(hp, amount): number`, `Vitals.heal(hp, amount): number`, `Vitals.canTakePill(hp): boolean`.
- Produces: `Taser.canStun(killer, now): boolean` y `Taser.applyStun(killer, now, cfg)`.
- Produces: `KillerBrain.step(b: Brain, input: Input, cfg): Brain`. `Brain` tiene `state: "Patrol" | "Chase" | "Search" | "Stunned" | "Stalk"`. `Input` tiene `now`, `dt`, `visibleTarget: string?`, `minRoomDistance: number?` (`nil` si todos están en refugios), `refugeCamper: string?`.

- [ ] **Step 1: Escribir las pruebas que fallan**

```lua
assert(Vitals.damage(100, 50) == 50 and Vitals.damage(50, 50) == 0)
assert(Vitals.heal(80, 50) == 100 and not Vitals.canTakePill(100))
-- Taser: aturde 10 s; no se puede durante el aturdimiento ni en los 5 s siguientes
assert(not Taser.canStun(k, 9) and not Taser.canStun(k, 14) and Taser.canStun(k, 15.1))
-- KillerBrain
-- Patrol + visibleTarget => Chase
-- Chase sin objetivo durante 8 s => Patrol
-- minRoomDistance >= 4 durante 120 s => Search; a los 119 s sigue en Patrol
-- minRoomDistance nil durante 120 s => sigue en Patrol
-- refugeCamper presente durante 30 s => Stalk; a los 20 s de Stalk => Patrol
-- Stunned ignora objetivos hasta terminar
```

- [ ] **Step 2:** Run: `lune run tests/run`. Expected: FAIL.
- [ ] **Step 3:** Implementar los tres módulos. `KillerBrain.step` no conoce posiciones, solo transiciones y temporizadores.
- [ ] **Step 4:** Run: `lune run tests/run`. Expected: PASS.
- [ ] **Step 5:** Commit `feat: reglas de vida, taser y estados del asesino`.

### Task 3: Generación de la mansión y ambiente

**Files:**
- Create: `src/server/Systems/Mansion.luau`, `src/server/Systems/Weather.luau`, `src/shared/Sounds.luau`, `src/shared/Remotes.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`, `src/client/Controllers/Ambience.luau`

**Interfaces:**
- Consumes: `MapGraph.default`, `Config`.
- Produces: `Mansion.build(): MansionRefs` con `rooms[id]` (`Part` de zona), `doors[n]` (`Model`), `spawn` y `hidingSpots[id]` (mínimo 4 `Attachment` por pieza, 8 libros repartidos en piezas 7 a 12).
- Produces: `Sounds` como única tabla de ID de audio y `Remotes.get(name)`.

- [ ] **Step 1:** Generar piezas, pasillos, 3 refugios y salida según el grafo, con velas (`PointLight`, máximo 6 por pieza) y ventanas.
- [ ] **Step 2:** Configurar `Lighting` de noche con niebla; en `Weather`, lluvia y rayo cada `Config.LightningInterval` (900 s).
- [ ] **Step 3:** En `Ambience`, parpadeo de velas y volumen de lluvia menor adentro. Un sonido que no carga no debe cortar el flujo.
- [ ] **Step 4:** Run: `rojo serve`, conectar y dar Play. Expected: aparición en el hall, todas las piezas recorribles por los pasillos, adentro solo luz de velas y sin errores en Output.
- [ ] **Step 5:** Commit `feat: mansión, velas y clima`.

### Task 4: Partida, objetos y puertas

**Files:**
- Create: `src/server/Systems/Round.luau`, `src/server/Systems/Items.luau`, `src/server/Systems/Vitality.luau`
- Create: `src/client/Controllers/Interact.luau`, `src/client/Controllers/Hud.luau`
- Test: `tests/ItemClaim.luau`, con `src/shared/Rules/ItemClaim.luau`

**Interfaces:**
- Consumes: `Progress`, `Vitals`, `MansionRefs`, `Remotes`.
- Produces: `Round.start()`, `Round.reset()`, `Round.getProgress(): Progress.State`, señales `Round.Won` y `Round.Reset`.
- Produces: `Vitality.damage(player, amount)`, `Vitality.getRoom(player): string?`.
- Produces: `ItemClaim.tryClaim(claims, itemId, playerId): boolean`.

- [ ] **Step 1: Escribir la prueba que falla:** `tryClaim(c, "key1", 1)` es `true`, y `tryClaim(c, "key1", 2)` es `false`. Run: `lune run tests/run`. Expected: FAIL.
- [ ] **Step 2:** Implementar `ItemClaim`. Run: `lune run tests/run`. Expected: PASS.
- [ ] **Step 3:** Implementar `Items`: ubicación al azar de llaves, libros, píldoras y recargas de taser. Validar distancia, línea de vista y frecuencia en el remote de interacción.
- [ ] **Step 4:** Implementar `Round`: puertas, salida, victoria de 15 s, reinicio que limpia todo y reinicio si no queda nadie.
- [ ] **Step 5:** Implementar `Vitality` (100 de vida, sin regeneración, reaparición conservando cargas) y correr: 6 s de energía y 10 s de recuperación.
- [ ] **Step 6:** Implementar `Interact` y `Hud`: vida, energía, cargas, llaves x/6, libros x/8, avisos y pantalla de victoria.
- [ ] **Step 7:** Agregar atajos de QA solo con `RunService:IsStudio()`: dar llaves, ir a una pieza, forzar rayo.
- [ ] **Step 8:** Probar en Studio. Expected: una partida completa hasta la victoria y su reinicio, sin asesino y sin errores en Output.
- [ ] **Step 9:** Commit `feat: partida, objetos, puertas e interfaz`.

### Task 5: Asesino, taser y susto

**Files:**
- Create: `src/server/Systems/Killer.luau`, `src/server/Systems/KillerModel.luau`, `src/server/Systems/TaserSystem.luau`
- Create: `src/client/Controllers/Scare.luau`, `src/client/Controllers/TaserClient.luau`

**Interfaces:**
- Consumes: `KillerBrain`, `Taser`, `MapGraph`, `Vitality.damage`, `Vitality.getRoom`, `Round.Reset`.
- Produces: `KillerModel.build(): Model`, `Killer.start()`, `Killer.stop()`, `Killer.stun(now): boolean`.

- [ ] **Step 1:** Implementar `KillerModel`: 1,80 m de alto, machete en la mano izquierda, sin brazo derecho, pelo largo, cara mitad piel y mitad carne, y un solo ojo.
- [ ] **Step 2:** Implementar `Killer`: inicio en la pieza 3, `KillerBrain.step` en cada tick, `PathfindingService` con velocidades de `Config`, golpe de 50 cada 3 s, refugios bloqueados y recolocación si queda trabado 10 s, fuera de la vista.
- [ ] **Step 3:** Cubrir en `Killer` a un objetivo que se desconecta o muere: se descarta en el mismo tick y se elige otro.
- [ ] **Step 4:** Implementar `TaserSystem` y `TaserClient`: 2 cargas una vez por jugador en el hall, recargas, alcance de 15 con línea de vista. Sin gastar carga si `Taser.canStun` es falso.
- [ ] **Step 5:** Implementar `Scare`: sonido y sacudida al verlo a menos de 30 unidades, con un intervalo de 20 s desde que se lo pierde de vista.
- [ ] **Step 6:** Probar en Studio. Expected: persigue, golpea 50, el taser lo frena 10 s, no entra a refugios y a los 2 min de estar lejos va a buscarte.
- [ ] **Step 7:** Commit `feat: asesino, taser y susto`.

### Task 6: Prueba final y balance

**Files:**
- Modify: `src/shared/Config.luau`, `README.md`

- [ ] **Step 1:** Run: `lune run tests/run`, `selene src`, `stylua --check src`. Expected: todo sin errores.
- [ ] **Step 2:** Partida completa en Studio con 1 jugador y con 2 (servidor local). Revisar cada punto de Review Focus.
- [ ] **Step 3:** Reemplazar en `Sounds` los ID que no carguen y ajustar `Config` según la prueba.
- [ ] **Step 4:** Documentar en `README.md` controles, cómo probar y atajos de QA.
- [ ] **Step 5:** Commit `chore: balance y documentación`.
