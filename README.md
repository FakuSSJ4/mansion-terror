# Mansión de terror

Juego cooperativo de terror para Roblox. Juntá las llaves de colores y los 4 pergaminos, dejalos en la estatua de lobo y escapá con la llave dorada sin que te alcance el asesino.

## Cómo probarlo

1. En esta carpeta, generá el archivo del juego:

   ```bash
   rojo build -o mansion-terror.rbxl
   ```

2. Abrí `mansion-terror.rbxl` con Roblox Studio y apretá **Play** (F5).
3. Los errores aparecen en la ventana **Output** (menú **View → Output**).

Para probar con 2 jugadores: pestaña **Test**, **Clients and Servers**, elegí 2 jugadores y **Start**.

## Controles

| Tecla | Acción |
|---|---|
| `E` | Agarrar objetos y abrir puertas |
| `Shift` izquierdo | Correr |
| Clic | Disparar el taser |
| `F` | Prender o apagar la linterna |

## Atajos de QA (solo en Studio)

| Tecla | Acción |
|---|---|
| `1` | Modo desarrollador: sin daño, todas las llaves, atravesás puertas y volás (`W A S D`, `Espacio` sube, `Ctrl` baja, doble `Espacio` deja de volar) |
| `K` | Dar todas las llaves |
| `2` | Dar todos los pergaminos |
| `3` | Ir a la pieza siguiente |
| `4` | Disparar un rayo |
| `5` | Recibir un golpe |
| `6` | Mostrar en Output el estado del asesino |
| `7` | Traer al asesino a tu pieza |
| `8` | Darte la linterna, la escalera y la llave dorada |
| `9` | Ir al pie de la gran escalera |
| `0` | Girar la vista 90° y nivelarla |
| `P` | Ir al pedestal del taser |
| `L` | Ir a las librerías del hall |
| `M` | Traer al asesino de smoking a tu pieza |
| `B` | Traer al carnicero a tu pieza |
| `T` | Recorrer alce, rinoceronte, puma, teclado, umbral, cama, sótano largo, mesa de carnicero, sala de juegos y bar |

## Sonidos

`src/shared/Sounds.luau` tiene los ID de audio y todavía están vacíos: hasta completarlos, el juego no tiene sonido.

## Desarrollo

```bash
lune run tests/run
```

```bash
selene src
```

```bash
stylua --check src tests
```

El balance se ajusta en `src/shared/Config.luau`. El diseño está en `docs/superpowers/specs/`.
