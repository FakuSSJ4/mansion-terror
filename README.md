# Mansión de terror

Juego cooperativo de terror para Roblox. Entrás por la puerta principal desde el patio (el lobby; en el atril de cada círculo, F abre un menú para elegir 1, 2 o 3 jugadores; al pisar el círculo arranca una cuenta de 10 segundos, del color del círculo, que se cancela si te bajás) y se cierra detrás tuyo. Juntá las llaves de colores y los 4 pergaminos (cada uno está en una habitación cerrada con código de 3 cifras; el código de cada habitación está escrito en una nota escondida por la casa), dejalos en la estatua de lobo, en la sala del fondo del sótano, y escapá por el túnel con la llave dorada sin que te alcance el asesino.

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
| `1` | Sacar o guardar el taser |
| `2` | Sacar o guardar la linterna |
| `3` | Usar el botiquín guardado (se lleva uno solo; cura 75). Las vendas curan 25 al agarrarlas |
| Clic | Disparar el taser (si lo tenés en la mano) |
| Clic derecho | Prender o apagar la linterna |

## Atajos de QA (solo en Studio)

| Tecla | Acción |
|---|---|
| `5` | Modo desarrollador: sin daño, todas las llaves, atravesás puertas y volás (`W A S D`, `Espacio` sube, `Ctrl` baja, doble `Espacio` deja de volar) |
| `K` | Dar todas las llaves |
| `J` | Dar todos los pergaminos |
| `=` | Ir a la pieza siguiente |
| `4` | Disparar un rayo (en la partida caen solos: a horas al azar dentro de una ventana de 3, 5 u 8 minutos, nunca en el primer minuto) |
| `H` | Recibir un golpe |
| `6` | Mostrar en Output el estado del asesino |
| `7` | Traer al asesino a tu pieza |
| `8` | Darte la linterna, la escalera y la llave dorada |
| `9` | Ir al pie de la gran escalera |
| `0` | Girar la vista 90° y nivelarla |
| `F` | Empezar una partida en solitario sin pasar por los círculos del lobby |
| `N` | Ir al primer círculo del lobby |
| `R` | Recorrer el lobby (de a una vista por vez) |
| `+` / `-` del teclado numérico | Darte 10 gemas / ir a la tienda del lobby |
| `V` | Probar la fuga: abre la puerta del túnel y arranca la secuencia |
| `0` del teclado numérico | Ir a la sala del lobo, al fondo del sótano |
| `1` del teclado numérico | Ir a la habitación 1 y abrir su teclado (los códigos salen en Output) |
| `U` | Pasar al siguiente animal del pedestal y ir a verlo |
| `Y` | Pasar a la siguiente cabeza de trofeo (pieza 1) y ir a verla |
| `G` / `Z` | Ir a ver las máquinas arcade / la barra del bar |
| `X` | Ir a ver, uno por uno, los pasillos tapiados de esta partida |
| `/` del teclado numérico | Prueba del cono de visión: te ve parado, te agachás detrás de un obstáculo y se imprime qué hace el asesino |
| `Insert` | Comprueba que todos los pasillos se pueden cruzar (el resultado sale en Output) |
| `P` | Ir al pedestal del taser |
| `L` | Ir a las librerías del hall |
| `M` | Traer al asesino de smoking a tu pieza |
| `B` | Traer al carnicero a tu pieza |
| `2` del teclado numérico | Repetir el primer encuentro: sienta al asesino en el sillón del living y te deja en la puerta |
| `F8` | Ir a ver, de a una por vez, la venda, el botiquín, la pila y las cajas fuertes 1 y 4 (las deja abiertas) |
| `Retroceso` | Repetir el primer encuentro del living (sienta al asesino y te deja en la puerta) |
| `T` | Recorrer alce, rinoceronte, puma, teclado, umbral, cama, sótano largo, mesa de carnicero, sala de juegos y bar |

## Sonidos

src/shared/Sounds.luau tiene todos los IDs de audio, del catálogo gratuito de Roblox (Creator Store). Se comprobó que cargan en Studio; si al publicar alguno se bloquea, se cambia ahí. En Studio, Av Pág (PageDown) vuelve a comprobar los candidatos y escribe el resultado en Output.

Suena: lluvia (baja), truenos y cuervos; puertas que crujen y destraban, cajón, goteo en la sala del lobo y viento en la salida del túnel; el rugido del asesino al empezar a perseguirte (gruñido del carnicero); el agua de la fuente en el lobby; acordes de victoria y de derrota; un zumbido grave de fondo en la mansión; latido que sube cuando hay un asesino cerca; golpe recibido, taser, portazo y golpes de la fuga; recoger objetos, clic de linterna, compra en la tienda; y música con fuego crepitando en el lobby.

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
