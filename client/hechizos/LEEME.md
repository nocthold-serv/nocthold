# Hechizos en el cliente

El cliente no trae los hechizos de Tibia: solo los nuestros, con iconos y
descripciones propios. El jugador los arrastra a la barra de acciones desde
la lista de hechizos y los lanza con un clic o una tecla, sin escribir nada.

## De dónde sale cada cosa

| Qué | Dónde | Quién lo usa |
|---|---|---|
| Nombre, palabras, id, maná, nivel, enfriamiento, vocación | `data-nocthold/scripts/nocthold/spells/*.lua` (`spell:name`, `spell:words`, `spell:id`...) | El servidor, y `configurar.py` lo copia al cliente al empaquetar |
| Descripción para el jugador | [`descripciones.json`](descripciones.json) | `configurar.py` |
| Iconos | [`iconos-32.png`](iconos-32.png) y [`iconos-20.png`](iconos-20.png), dibujados por [`dibujar_iconos.py`](dibujar_iconos.py) | `configurar.py` los pone en lugar de los de Tibia |

Cada hechizo tiene un **id fijo entre 1001 y 1030** (`spell:id(...)` en el
servidor). Sirve para dos cosas: el servidor lleva el enfriamiento de cada
hechizo por su id (antes todos tenían 0 y compartían enfriamiento), y el
cliente busca el icono en la tira por ese número: el id 1001 es el primer
icono, el 1002 el segundo, etc. **No cambies el id de un hechizo que ya existe.**

Las palabras (`vorn skel`, `sylva mei`, `aeth ir`...) son inventadas: el
jugador no las escribe, solo las ve en el chat al lanzar el hechizo. Cada
clase tiene su raíz: `vorn`/`stal`/`hrum` el Guardián, `sylva`/`ronce` el
Custodio y `aeth` el Arcanista.

## Añadir o cambiar un hechizo

1. En el servidor, el fichero `.lua` del hechizo con `spell:id(1031)` (el
   siguiente libre) y sus palabras.
2. Su descripción en `descripciones.json`, con el mismo nombre que `spell:name`.
3. Su icono: añade el nombre **al final** de `ORDEN` en `dibujar_iconos.py`,
   escribe su función de dibujo en `DIBUJOS` y ejecuta
   `python client/hechizos/dibujar_iconos.py` (necesita `pip install pillow`).
   Mira `muestra.png` para ver cómo quedan.
4. PR. El workflow **Cliente Windows** falla si falta una descripción o un
   icono, o si hay ids o palabras repetidos.

Los cambios de hechizos llegan a los jugadores con una release nueva del
cliente (`cliente-vX.Y.Z`); el `.exe` no cambia, así que Windows no lo vuelve
a bloquear.
