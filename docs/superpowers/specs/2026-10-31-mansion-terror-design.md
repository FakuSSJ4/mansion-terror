# Mansión de terror: diseño

Fecha: 2026-10-31

## Retoques acordados (reemplazan lo que contradigan más abajo)

- **Cámara:** primera persona fija.
- **Mapa:** planta baja (hall con gran escalera, living, comedor, sala de música, cocina), sótano de 2 piezas al que se baja desde la cocina, primer piso de 6 piezas (dormitorio incluido) y altillo ("cobertizo") de 1 pieza. Refugios junto al living, en el sótano y junto al dormitorio.
- **Recorrido:** llaves de color, cada una abre la puerta de su color, alternando pisos: roja (living) abre la gran escalera; azul (dormitorio) abre el comedor; verde (comedor) abre la pieza 9; violeta (pieza 10) abre la sala de música; amarilla (sala de música) abre la pieza 11; negra (pieza 12) abre el sótano, en la cocina.
- **Librerías:** seis en la pared del fondo del hall, con huecos donde puede aparecer loot.
- **Arma:** hacha con mango negro, cabeza y empuñadura amarillas.
- **Asesinos:** el principal mata con 3 golpes (34 de daño). El segundo, de smoking y con bastón estoque, solo recorre el primer piso sin subir al cobertizo, es más lento y mata con 2 golpes (50). Ambos esperan 2 s tras golpear.
- **Pergaminos:** son 4: uno en el sótano, uno en el altillo, uno en una pieza de planta baja con puerta de color y uno en el primer piso. Se dejan en la estatua de lobo del hall: su cajón da la llave dorada del lobo, que abre la puerta principal.
- **Escalera de mano:** siempre en el sótano, se lleva encima y se coloca bajo la trampilla. Se cae si el dueño muere o se va, igual que la llave dorada.
- **Puertas y asesino:** solo cruza puertas ya abiertas y sube al altillo si la escalera está puesta. Arranca en el living y espera 20 s desde que alguien empieza a jugar.
- **Muerte:** el que muere no reaparece: mira a los que siguen vivos (clic cambia de jugador) y sus objetos quedan donde cayó. Cuando mueren todos, la partida se reinicia con la misma dificultad.
- **Hall:** doble altura, escalera imperial con dos rejas que se abren juntas, galería (primer ambiente del primer piso), columnas y ventanales. La estatua de lobo queda en el centro. Colores: los mismos de toda la casa.
- **Puertas:** una o dos hojas que giran sobre bisagras, con paneles dibujados en la superficie y una placa del color de la llave. Las de la escalera y el sótano son rejas de hierro.
- **Dificultad:** Normal o Difícil, elegida tras el tutorial por el primer jugador. Difícil reduce a la mitad píldoras, pilas y tasers escondidos; el taser del hall no cambia.
- **Tutorial:** al entrar, con opción de omitirlo. Mientras está abierto no se puede caminar ni recibir daño.
- **Luz a distancia:** las velas se apagan gradualmente con la distancia, así lo lejano queda oscuro.
- **Asesino:** cruza la trampilla apareciendo del otro lado. No acecha los refugios: si su objetivo entra a uno, lo abandona y sigue patrullando.
- **Taser:** se lleva uno, con 1 descarga, y desaparece al usarlo. Uno por jugador en el hall y 4 escondidos.
- **Linterna:** una sola, sobre una mesa al lado de la estatua de lobo; tecla `F`; 2 minutos de batería. 6 pilas de 1 minuto cada una. Se cae si el dueño muere o se va.
- **Aspecto:** paredes blanco grisáceo, cielo raso marrón oscuro, piso rojo sangre, cuadros medievales, alfombras y candelabros. Ventanales grandes y bosque afuera.
- **Cuervos:** evento cada 20 minutos; suena cuando se cargue el audio.

## Objetivo

Juego de terror cooperativo para Roblox. Los jugadores aparecen en la entrada de una mansión en una noche de lluvia, buscan 6 llaves y 8 libros o pergaminos mientras los persigue un asesino, y ganan al escapar.

La partida se considera lograda si un jugador, solo o en grupo, puede completarla de principio a fin, y si el asesino genera presión constante sin que morir sea inevitable.

## Plataforma y estructura

- Roblox, con Rojo y Luau estricto, igual que `spore-celula`.
- Proyecto en `Proyectos/mansion-terror`.
- La mansión, el asesino y los sistemas se generan por código.
- El servidor es la autoridad sobre vida, objetos, puertas, asesino y estado de la partida. El cliente solo muestra la interfaz, los efectos y los sonidos locales.
- Todos los valores de balance están en `src/shared/Config.luau`.
- Sin guardado: cada partida arranca de cero.

## Mapa

Las piezas se conectan en este orden:

| Orden | Pieza | Contenido |
|---|---|---|
| 0 | Hall de entrada | Punto de aparición, primer taser, ventanas al exterior |
| 1 a 6 | Ala de las llaves | Una llave por pieza |
| 7 a 12 | Ala final | Los 8 libros repartidos |
| 13 | Salida | Puerta final |

Además hay 3 refugios conectados a los pasillos: uno junto a la pieza 2, uno junto a la pieza 5 y uno junto a la pieza 9. Cada pieza es un nodo de un grafo, y la distancia entre piezas se mide en cantidad de nodos sobre ese grafo.

## Progreso

- Del hall a la pieza 1 se pasa sin llave.
- La llave N se encuentra en la pieza N y abre la puerta hacia la pieza N+1, así que la llave 6 abre la puerta al ala final (pieza 7).
- Cada llave y cada libro aparece en un escondite al azar entre varios posibles de su zona (detrás de muebles, dentro de cajones, en rincones oscuros). Cada pieza tiene al menos 4 escondites.
- Las llaves y los libros son del equipo. Una puerta abierta queda abierta para todos.
- Con los 8 libros se abre la salida. La partida se gana cuando un jugador la cruza; ganan todos.
- Al terminar se muestra la pantalla de victoria durante 15 s y la partida se reinicia.

## Jugador

- 100 de vida, sin regeneración automática.
- Velocidad caminando: 12. Corriendo: 20, con 6 s de energía y recuperación en 10 s.
- Al llegar a 0 reaparece en el hall con 100 de vida y las cargas de taser que tenía. El equipo no pierde llaves ni libros.

## Asesino

**Aspecto:** 1,80 m de alto (proporcional al personaje de Roblox), machete en la mano izquierda, sin brazo derecho, pelo largo, cara partida a la mitad con piel en un lado y carne en el otro, y sin un ojo.

**Estados:**

| Estado | Comportamiento | Velocidad |
|---|---|---|
| Patrulla | Camina entre piezas al azar | 10 |
| Persecución | Va hacia un jugador que ve o que corre a menos de 20 unidades | 15 |
| Búsqueda | Va directo a la pieza del jugador más cercano | 18 |
| Aturdido | Quieto, sin atacar | 0 |
| Acecho | Espera cerca de la puerta de un refugio | 10 |

**Reglas:**

- Golpe cuerpo a cuerpo: 50 de daño, con 3 s de espera entre golpes.
- Si ningún jugador está a menos de 4 piezas durante 2 minutos, pasa a Búsqueda. No se teletransporta. Los jugadores en refugios no cuentan como objetivo de Búsqueda; si todos están en refugios, sigue en Patrulla.
- Si pierde de vista a su objetivo durante 8 s, vuelve a Patrulla.
- Hay un solo asesino, sin importar la cantidad de jugadores.
- Empieza en la pieza 3, para dar tiempo al principio de la partida.
- Nunca entra a un refugio. Si un jugador pasa más de 30 s adentro, el asesino pasa a Acecho junto a esa puerta durante un máximo de 20 s.

## Objetos

- **Taser:** se empieza sin él. El del hall da 2 cargas; cada jugador puede agarrarlo una vez. Hay 4 recargas más de 1 carga repartidas por el mapa. Alcance de 15 unidades, requiere línea de vista. Aturde 10 s, y después el asesino tiene 5 s durante los que no se lo puede volver a aturdir.
- **Píldoras:** curan 50, sin pasar de 100. Hay 8 repartidas por el mapa, en escondites al azar. No se acumulan: se consumen al agarrarlas y no se pueden agarrar con la vida llena.

## Ambiente

- Hora fija de noche, niebla, sin luz global útil dentro de la mansión.
- La iluminación interior son solo velas con `PointLight` que parpadea. Para cuidar el rendimiento, cada pieza tiene un máximo de 6 luces.
- Lluvia con partículas afuera y sonido de lluvia que baja de volumen adentro.
- Un rayo cada 15 minutos: destello, trueno y luz breve por las ventanas. Valor configurable.
- **Susto:** sonido fuerte y sacudida de cámara cuando un jugador ve al asesino a menos de 30 unidades. Vuelve a sonar solo si pasaron 20 s desde que lo perdió de vista.

## Interfaz

Muestra vida, energía, cargas de taser, llaves (x/6) y libros (x/8), avisos cortos en español y la pantalla de victoria. Controles: `E` para interactuar, `Shift` para correr, clic para disparar el taser.

## Errores y casos borde

- Si un jugador se desconecta con el grupo a medio camino, el progreso sigue. Si no queda nadie, la partida se reinicia.
- Si alguien entra a mitad de partida, aparece en el hall con el progreso actual.
- Si el asesino queda trabado sin poder avanzar más de 10 s, se recoloca en la puerta de la pieza más cercana, fuera de la vista de los jugadores.
- Toda interacción se valida en el servidor: distancia, línea de vista y límite de frecuencia.
- Si un sonido de la biblioteca no carga, el juego sigue sin él. Sus ID quedan en un solo módulo para poder reemplazarlos.

## Pruebas

- Pruebas de la lógica pura: grafo y distancias, progreso de llaves y libros, cálculo de vida y transiciones del asesino.
- Atajos de QA disponibles solo en Studio: dar todas las llaves, ir a una pieza y disparar un rayo.
- Prueba manual en Studio con partida completa, con 1 y con 2 jugadores.

## Fuera de alcance

Guardado entre sesiones, compras y varios mapas.
