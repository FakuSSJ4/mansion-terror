# Mansión de terror: contexto para Claude

Respondé en español (Argentina), corto y al grano. Antes de cambios grandes, mostrá un plan corto y esperá el OK. No borres archivos sin preguntar. Claude se reserva para lo difícil: las tareas simples sugerí hacerlas con Gemini o DeepSeek en Cursor.

Juego de terror cooperativo para Roblox en Luau estricto, con Rojo, Selene, StyLua y pruebas en Lune. Diseño vigente: `docs/superpowers/specs/2026-10-31-mansion-terror-design.md` (los "Retoques acordados" mandan sobre lo de abajo). Atajos de QA: `README.md`.

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

Abrí el `.rbxl` en Studio. Para sincronizar en vivo, corré `rojo serve --port 34900` y conectá el plugin de Rojo a ese puerto.

## Estado

Probado en Studio solo con 1 jugador. Último trabajo: patio delantero con ángel, salida por su portón, luz en modo desarrollador.

Sin probar todavía:
- Partida completa a pie, con las llaves alternando pisos.
- Partida con 2 jugadores: espectador y objetos que caen.
- Asesinos usando las escaleras, entrando a las salas nuevas o saliendo al patio.
- Taser contra el asesino de smoking.
- Carnicero subiendo a la planta baja y sus 5 golpes.
- De cerca: máquinas de paintball, instrumentos de la mesa, cadáveres tirados y cama.

Para más adelante, a pedido del usuario: sonidos (ID vacíos en `src/shared/Sounds.luau`) y niveles de gráficos bajo, medio y alto.

## Preferencias del usuario

- Conservar los colores: paredes blanco grisáceo, cielo raso marrón oscuro, piso rojo sangre.
- Preferir pocas partes y detalles dibujados, para no saturar el sistema.
- La casa va bien oscura; el modo desarrollador (tecla `1`) ve todo iluminado.
- Quiere que Claude pruebe en Studio y le cuente con honestidad qué no pudo verificar.

## Reglas del código

- Lógica pura en `src/shared/Rules`, sin APIs de Roblox, con pruebas en `tests/`. `Config.luau` no puede usar `Color3` porque Lune no lo tiene.
- El servidor es la autoridad. Los valores de balance van en `src/shared/Config.luau`.
- Asesinos en `Config.Killers`; cada uno es una instancia en `Killer.luau` y puede limitarse con `rooms`.
- `decor()` no choca. Lo que queda en el centro de una pieza debe dejar pasar a los asesinos (grupo `KillerPass`), porque pasan por ahí.
- Evitá caras coplanares (umbrales, techos de pasillo): en Roblox parpadean y se ven bugueadas.

## Probar con computer-use

- Stop en (143,46), Play en (86,46). El mouse rota la cámara según su distancia al centro (630,358), así que hacé clic ahí para dar foco. Tutorial: `Q`, dificultad: `N`.
- La tecla `T` recorre las vistas de QA; `0` gira 90°; `6` imprime el estado de los asesinos.
- No uses `open_application` con Studio abierto: abre otra ventana. Si otra app está al frente, parate y avisá en vez de robarle el foco.
- No uses Ctrl+A ni Delete durante Play. La barra de comandos es multilínea y conserva líneas viejas: Enter no ejecuta, se usa el botón Ejecutar.
- Rojo se cae a veces al editar archivos; si pasa, relanzalo y reconectá el plugin.
