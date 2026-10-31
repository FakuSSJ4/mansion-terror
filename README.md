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

## Atajos de QA (solo en Studio)

| Tecla | Acción |
|---|---|
| `F1` | Dar todas las llaves |
| `F2` | Dar todos los escritos |
| `F3` | Ir a la pieza siguiente |
| `F4` | Disparar un rayo |
| `F6` | Recibir un golpe |

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
