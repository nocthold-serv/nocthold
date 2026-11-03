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
   Con un GOD: `/nocthold mapa` lista los mapas y `/nocthold mapa sala_prueba` te lleva a su entrada.

## Qué significa cada letra

| Letra | Casilla |
|---|---|
| `.` | suelo |
| `#` | pared |
| `+` | puerta (tiene que ir en medio de una pared recta) |
| `P` | suelo en zona protegida (no se puede atacar) |
| `E` | entrada (obligatoria, solo una) |
| `J` | jefe (si hay varias: `jefe`, `jefe2`...) |
| `1` a `9` y otras mayúsculas | suelo con un punto con nombre (`1`, `2`... `n`) para los scripts |
| espacio o `~` | nada |

Con `paredes_auto: si` (lo normal) no hace falta dibujar paredes: toda casilla vacía que toca
un suelo (también en diagonal) se convierte en pared. Las paredes se orientan solas
(horizontal, vertical, esquina o poste) con las mismas reglas que el pincel del RME.

Los puntos quedan en el mapa como *waypoints* con el nombre `<mapa>.<punto>`, por ejemplo
`sala_prueba.jefe`. Desde Lua: `getWaypointPositionByName("sala_prueba.jefe")`.

## Materiales

Están en `materiales.json`. Para añadir uno, busca los IDs en el RME y añádelos ahí; el test
comprueba con `data/items/appearances.dat` que los suelos son suelo y las paredes bloquean.

- Suelos: `piedra gris`, `piedra`, `marmol negro`, `adoquin marron`, `tierra de cueva` (mezcla piezas).
- Paredes: `piedra` (con puertas), `roca`, `piedra clara`.

## Qué genera

En `data-nocthold/world/custom/`: `<nombre>.otbm` y sus cuatro ficheros de monstruos, NPC,
casas y zonas (vacíos de momento). Canary carga todos los `.otbm` de esa carpeta al
arrancar con `DATA_PACK=data-nocthold`. Producción no usa esta carpeta.

En `data-nocthold/scripts/lib/nocthold_mapas.lua`: la lista de mapas con sus puntos y lo que
debe haber en cada casilla (lo usan `/nocthold mapa` y la prueba automática).

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
- Sin bordes de suelo ni decoración: eso se hace en el RME.
