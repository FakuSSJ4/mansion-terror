# Mansión de terror: contexto para Claude

Respondé en español (Argentina), corto y al grano. Antes de cambios grandes, mostrá un plan corto y esperá el OK. No borres archivos sin preguntar. Claude se reserva para lo difícil: las tareas simples sugerí hacerlas con Gemini o DeepSeek en Cursor.

Juego de terror cooperativo para Roblox en Luau estricto, con Rojo, Selene, StyLua y pruebas en Lune. Cómo se juega y los atajos de QA: `README.md` (es lo que manda; los atajos cambiaron respecto de versiones viejas). Diseño: `docs/superpowers/specs/2026-10-31-mansion-terror-design.md`, parcialmente desactualizado: donde choque con el README o el código, mandan estos.

## Poner en marcha en otra PC

```bash
rokit install
```

```bash
lune run tests/run
```

```bash
rojo build -o mansion-terror.rbxl
```

Abrí el `.rbxl` en Studio y dale Probar. Para sincronizar en vivo, corré `rojo serve --port 34900` y conectá el plugin de Rojo a ese puerto.

## Estado

Hecho en dos PC: el trabajo de la primera (asesinos, patio, salas) y el de la segunda (lobby, fuga, cajas fuertes, dificultades, sonidos). Las pruebas de Lune pasan (86); el juego completo se probó a mano solo en parte.

Cómo es hoy:
- El juego arranca en el lobby, en el patio. Se entra por la puerta principal, que se cierra detrás. Hay 1, 2 o 3 jugadores según el círculo.
- 6 llaves de colores, 4 pergaminos en cajas fuertes con código de 3 cifras (el código está escrito en notas por la casa) y la estatua de lobo, en la sala del fondo del sótano, que da la llave dorada. Se escapa por un túnel con una secuencia de fuga.
- Cuatro asesinos en `Config.Killers`: el principal (3 golpes, toda la casa), el del smoking (2 golpes, solo el piso de arriba) y dos carniceros (5 golpes, solo el sótano y la cocina).
- Dificultades Fácil, Normal y Pesadilla (esta se desbloquea al ganar 3 partidas), gemas y tienda del lobby.
- Los sonidos ya están en `src/shared/Sounds.luau`.
- Primer encuentro (`Systems/Cinema` y `Controllers/Cinema`): el asesino principal arranca sentado en un Chesterfield del living (room1) mirando un proyector, con un whisky. La primera vez que alguien entra hay una cinemática de unos 10 s (Q la saltea) y después sale a cazar; si nadie entra en 150 s, se levanta solo. La película de la pantalla es provisoria (cuenta regresiva): la definitiva va en el marco `Imagen` (ver `Controllers/Projector`).
- Los asesinos ignoran al jugador en modo desarrollador.

Sin comprobar a mano todavía: el lobby, la fuga por el túnel, las cajas fuertes con código, la partida con 2 o más jugadores (espectador y objetos que caen) y el taser contra el asesino de smoking. Para más adelante, a pedido del usuario: niveles de gráficos bajo, medio y alto.

## Preferencias del usuario

- Conservar los colores: paredes blanco grisáceo, cielo raso marrón oscuro, piso rojo sangre.
- Preferir pocas partes y detalles dibujados, para no saturar el sistema.
- La casa va bien oscura; el modo desarrollador (tecla `5`) ve todo iluminado.
- Quiere que Claude pruebe en Studio y le cuente con honestidad qué no pudo verificar.

## Reglas del código

- Lógica pura en `src/shared/Rules`, sin APIs de Roblox, con pruebas en `tests/`. `Config.luau` no puede usar `Color3` porque Lune no lo tiene.
- El servidor es la autoridad. Los valores de balance van en `src/shared/Config.luau`.
- Cada asesino es una instancia en `Killer.luau` y puede limitarse a ciertas piezas con `rooms`.
- `decor()` no choca. Lo que queda en el centro de una pieza debe dejar pasar a los asesinos (grupo `KillerPass`), porque pasan por ahí.
- Evitá caras coplanares (umbrales, techos de pasillo): en Roblox parpadean y se ven bugueadas.
- Rojo solo incluye archivos `.luau`: una copia como `Mansion.luau.bak` no entra al juego, pero ensucia el repo. Para respaldar, usá git.

## Probar con computer-use

- Stop en (143,46), Play en (86,46). El mouse rota la cámara según su distancia al centro (630,358), así que hacé clic ahí para dar foco. Los atajos de QA y los del tutorial están en el README; antes de usarlos, comprobá que no cambiaron.
- La tecla `0` gira la vista 90° y `6` imprime el estado de los asesinos.
- No uses `open_application` con Studio abierto: abre otra ventana. Si otra app está al frente, parate y avisá en vez de robarle el foco.
- No uses Ctrl+A ni Delete durante Play. La barra de comandos es multilínea y conserva líneas viejas: Enter no ejecuta, se usa el botón Ejecutar.
- Rojo se cae a veces al editar archivos; si pasa, relanzalo y reconectá el plugin.
