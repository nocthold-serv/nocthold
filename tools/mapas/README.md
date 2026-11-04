# Generador de mapas de Nocthold

Convierte un **plano dibujado con letras** en un mapa `.otbm` que Canary carga solo.
La idea: el programa pone la estructura (salas, pasillos, paredes, puertas, entrada,
puntos para los jefes) y después se decora a mano en el RME.

## Paso a paso

1. Copia `planos/sala_prueba.txt` con otro nombre dentro de `planos/` (por ejemplo `planos/mi_sala.txt`).
2. Ábrelo con cualquier editor de texto y cambia:
   - `nombre:` minúsculas, números y `_` (sin tildes ni espacios). Tiene que ser distinto en cada plano.
   - `origen:` la casilla X Y Z donde empieza el dibujo (esquina de arriba a la izquierda).
     No puede pisar otro plano ni la sala de La Forja Caída (X 64000-64080, Y 64000-64030, piso 7).
   - `suelo:` y `pared:` uno de los materiales de la tabla de abajo.
   - El dibujo, debajo de `plano:`.
3. Desde la carpeta del repositorio, ejecuta:
   ```
   python3 tools/mapas/generar_mapa.py
   ```
   (en Windows: `py tools\mapas\generar_mapa.py`). Dice cuántas casillas ha hecho o, si algo
   está mal, en qué fila y columna.
4. Sube los cambios en un PR. GitHub arranca el servidor de verdad con el mapa y comprueba
   casilla a casilla que está como en el plano.
5. Cuando se fusiona en `develop`, el servidor de pruebas lo carga en el siguiente arranque.
   Junto al templo aparece un portal (campo mágico) por cada mapa generado, en orden alfabético:
   al pisarlo te lleva a su entrada. Sin comandos.

## Qué significa cada letra

| Letra | Casilla |
|---|---|
| `.` | suelo |
| `#` | pared |
| `+` | puerta (tiene que ir en medio de una pared recta) |
| `P` | suelo en zona protegida (no se puede atacar) |
| `E` | entrada (obligatoria, solo una) |
| `J` | jefe (si hay varias: `jefe`, `jefe2`...) |
| `1` a `9` y otras mayúsculas | suelo con un punto con nombre (`1`, `2`... `k`) para los scripts |
| `a` a `z` (minúsculas) | un monstruo del grupo (pull) de esa letra: todas las `c` son el grupo `c` |
| espacio o `~` | nada |

Con `paredes_auto: si` (lo normal) no hace falta dibujar paredes: toda casilla vacía que toca
un suelo (también en diagonal) se convierte en pared. Las paredes se orientan solas
(horizontal, vertical, esquina o poste) con las mismas reglas que el pincel del RME.

Opciones de grupos y puntos (encima de `plano:`):

```
grupo c: Sabueso de Ceniza   # qué monstruo va en las casillas 'c'
radio c: 4                   # radio de aggro del grupo, en casillas (1-15; si no, el de por defecto)
punto K: jefe1               # nombre del punto marcado con 'K' (si no, se llama 'k')
destino S: templo            # la 'S' es un portal que lleva al templo del jugador
destino T: jefe1             # la 'T' es un portal a otro punto de este mapa
destino U: 32369 32241 7     # ...o a una casilla concreta X Y Z
```

Los grupos se guardan en `nocthold_mapas.lua` (`grupos[letra] = {monstruo, radio, posiciones}`)
para que el script de aggro cree los monstruos y su zona invisible. El `.otbm` no lleva monstruos.

Los puntos quedan en el mapa como *waypoints* con el nombre `<mapa>.<punto>`, por ejemplo
`sala_prueba.jefe`. Desde Lua: `getWaypointPositionByName("sala_prueba.jefe")`.

## Zonas: varios suelos y paredes en un mismo mapa

`suelo:` y `pared:` son los de todo el mapa. Para cambiarlos en una parte, se define una zona
con una letra y se dibuja debajo del plano, en una **capa** que va casilla a casilla con él:

```
zona f: suelo fango negro, pared huesos   # las dos cosas son opcionales
zona n: suelo marea negra

plano:
...el dibujo de siempre...
capa zonas:
     fffff
     ffnnf
```

Las paredes automáticas toman la zona del suelo de al lado. Si una zona tiene un suelo que
no se pisa (agua, brea), esas casillas no se pueden pisar y el programa avisa si encima hay una
entrada, un punto o un monstruo.

**Bordes.** Algunos suelos tienen borde (`bordes` en `materiales.json`, los mismos del RME):
el agua, la brea, el barro... El programa pone el borde en las casillas de alrededor, como el
pincel del RME, y solo el del suelo de más `orden` sobre el de menos. Ojo: la orilla del agua
profunda y del agua negra tampoco se pisa (como en Tibia).

## Objetos de decoración

Igual, con una capa de objetos. Cada letra es una lista de IDs (sale uno u otro según la
casilla, siempre el mismo) o, para colgar en la pared, `pared <ID horizontal> <ID vertical>`:

```
objeto L: pared 11054 11055   # antorcha de calavera (solo en paredes rectas)
objeto p: 10837 10838 10839   # columna de calaveras (no se pisa)
objeto h: 3114 3115 3116      # huesos por el suelo

capa objetos:
  L
     p  h
```

Lo colgado solo se ve en las paredes con su cara a la vista: las horizontales con suelo al sur
y las verticales con suelo al este. Si una capa necesita llegar a la fila de paredes de encima
del dibujo, deja una fila en blanco al principio del plano (y lo mismo con una columna a la
izquierda): las capas cuentan las filas tal como están escritas.

La prueba del servidor revisa también cada objeto y si la casilla se pisa o no.

## Materiales

Están en `materiales.json`. Para añadir uno, busca los IDs en el RME y añádelos ahí; el test
comprueba con `data/items/appearances.dat` que los suelos son suelo, que las paredes bloquean y
que las puertas se abren sin llave.

- Suelos: `piedra gris`, `piedra`, `marmol negro`, `adoquin marron`, `tierra de cueva`, `templo mojado`,
  `templo mojado oscuro`, `marmol abisal`, `marmol abisal roto`, `agua somera`, `musgo`, `fango negro`,
  `moho`, `losas oscuras`, `agua de sangre`; y sin pisar: `marea negra` (brea), `agua profunda`, `agua negra`.
- Paredes: `piedra` (con puertas), `roca`, `piedra clara`, `piedra maciza`, `piedra oscura`, `huesos`, `manos`.
  Una pieza de pared con varios IDs es una lista de variantes.

## Diseños que no van al repositorio

El repositorio es público. Para un diseño propio, guarda los planos en otra carpeta y genera allí:

```
python3 tools/mapas/generar_mapa.py --planos MI_CARPETA_DE_PLANOS --salida MI_CARPETA_DE_MAPAS
```

## Qué genera

En `data-nocthold/world/custom/`: `<nombre>.otbm` y sus cuatro ficheros de monstruos, NPC,
casas y zonas (vacíos de momento). Canary carga todos los `.otbm` de esa carpeta al
arrancar con `DATA_PACK=data-nocthold`. Producción no usa esta carpeta.

En `data-nocthold/scripts/lib/nocthold_mapas.lua`: la lista de mapas con sus puntos y lo que
debe haber en cada casilla (lo usan los portales de `mapas_portales.lua` y la prueba automática).

No edites a mano lo generado: cambia el plano y vuelve a ejecutar el programa. GitHub falla
si lo generado no coincide con los planos.

## Decorar en el RME

El `.otbm` generado se abre en el RME como cualquier mapa (con los gráficos del cliente 15.x).
Si lo decoras allí, ese mapa pasa a ser "a mano": borra su plano de `planos/` (si no, el
programa lo vuelve a generar encima) y guarda el `.otbm` del RME en `data-nocthold/world/custom/`.
El programa nunca borra mapas: si quitas un plano, borra tú sus ficheros si ya no los quieres.

## Pruebas

```
python3 -m unittest discover -s tools/mapas -v
```

## Límites de este prototipo

- Un piso por plano (sin escaleras entre pisos).
- Sin monstruos ni NPC colocados en el mapa (los pone el script de la mazmorra).
- Objetos de una sola casilla (nada de estatuas o sarcófagos de varias casillas).
- Bordes solo de los suelos que tienen `bordes` en `materiales.json`.
