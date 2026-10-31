# Mansión de terror

Juego cooperativo de terror para Roblox. Juntá 6 llaves y 8 escritos, y escapá sin que te alcance el asesino.

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
| `1` | Dar todas las llaves |
| `2` | Dar todos los escritos |
| `3` | Ir a la pieza siguiente |
| `4` | Disparar un rayo |
| `5` | Recibir un golpe |
| `6` | Mostrar en Output el estado del asesino |
| `7` | Traer al asesino a tu pieza |
| `8` | Darte la linterna y la escalera |
| `9` | Ir al pie de la gran escalera |
| `0` | Girar la vista 90° y nivelarla |
| `P` | Ir al pedestal del taser |

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
