# data-nocthold: datapack propio (en pruebas)

Contenido propio del proyecto, empezando por el primer paquete del compañero (v0.2.0, que venía con el nombre provisional "UMBRAL"; el juego se llama Nocthold).

Esta carpeta **no es un datapack completo**: solo lleva nuestros archivos. Al
construir la imagen Docker se copia `data-canary` a `/canary/data-nocthold` y se
ponen estos archivos encima (ver `docker/Dockerfile.x86`). Así, cuando Canary
se actualice, no hay que fusionar una copia entera de `data-canary`.

## Qué hay (1.0.0-alpha.1)

| Carpeta | Qué es | Estado |
|---|---|---|
| `monster/nocthold/` | 7 monstruos (4 normales y 3 jefes con fases: al 70 % y al 35 % de vida llaman refuerzos) | Dan oro; sin experiencia todavía. Aspecto provisional. |
| `npc/nocthold_npcs.lua` | 5 NPC con diálogo | Se colocan solos al arrancar. El Cronista de Llaves da la piedra-llave y la Archivista dice el estado. |
| `scripts/nocthold/spells/` | 30 hechizos: Guardian (knight), Warden (druid) y Arcanist (sorcerer) | Se lanzan con `nocthold <palabra>` (lista: `/nocthold spells`). Balance sin ajustar. |
| `scripts/nocthold/runtime/` | La Forja Caída: 6 encuentros, llaves 0-10, cronómetro y recompensa en oro. `dungeon_entrance.lua`: portal, altar, piedra-llave, barrera y salidas | Una sola arena compartida (un grupo a la vez); la expedición en curso se pierde al reiniciar (la piedra-llave no). |
| `scripts/lib/nocthold.lua` | Lista de lo que debe cargarse y `Nocthold.latin1()` | Lo usan el aviso de arranque y `/nocthold status`. |
| `scripts/nocthold/nocthold_startup.lua` | Al arrancar escribe `[NOCTHOLD] OK ...` en el log | La comprobación de GitHub busca esa línea. |
| `scripts/nocthold/nocthold_admin.lua` | `/nocthold status`, `spells`, `golpe`, `mapa`, `forja`, `llave` y `reset` (solo god) | `/nocthold mapa [nombre]` lleva al GOD a la entrada de un mapa generado. |
| `world/custom/` | Mapas `.otbm` generados con `tools/mapas/generar_mapa.py` a partir de planos de letras | Canary los carga solos al arrancar. De momento, `sala_prueba` (X 63999-64017, Y 64099-64116, piso 7). |
| `scripts/lib/nocthold_mapas.lua` | Lista de mapas generados, sus puntos y lo que hay en cada casilla | GENERADO: no editar a mano. |

### Probar la mazmorra (sin comandos)

Los jugadores no escriben ningún comando: todo está en el mapa.

1. Al arrancar el servidor se genera sola la sala en X=64000, Y=64000, Z=7 (con el suelo del
   templo), con los 5 NPC, y aparece un **portal** (campo mágico) a 2-4 casillas del templo.
2. El portal lleva a la **sala de entrada**. Allí, el **Cronista de Llaves** da la piedra-llave:
   `hi`, `llave` y el nivel (`0` a `10`), o `llave 5` de una vez. Va a la mochila y lleva el
   nivel en el nombre. Solo una por jugador: pedir otra cambia la que tengas.
3. El líder del grupo (1 a 5 jugadores) usa el **altar** de la entrada (o la piedra-llave junto
   a él). Entran ya los del grupo que están en la sala de entrada y empieza el cronómetro.
4. El pasillo tiene una **barrera**: solo pasan los de la expedición. Quien muere vuelve al
   templo, cruza el portal y pasa la barrera para reincorporarse.
5. Avisos solos: cada fase con el tiempo que queda, la mitad del tiempo y el último minuto.
   La **Archivista Nima** dice el estado si le preguntas `estado`.
6. Al terminar a tiempo, la piedra-llave del líder sube un nivel y aparece un **portal en la
   última sala** que devuelve a la entrada (a los 90 s vuelve solo quien siga dentro). El
   **portal de la entrada** lleva al templo.
7. Si nadie de la expedición está dentro durante 3 minutos, la sala se libera.
8. Desde la llave 4 sale un Sabueso más en cada grupo; desde la 7, un Coloso más con el jefe final.

Para probar como GOD: `/nocthold forja` (ir a la entrada), `/nocthold llave 7` (piedra-llave en
tu mochila) y `/nocthold reset` (vaciar la mazmorra). El GOD cruza la barrera siempre.

Tests sin servidor: `luajit tests/lua/test_nocthold_datapack.lua` y `luajit tests/lua/test_nocthold_dungeon.lua`.

El diseño (GDD, magias, talentos, objetos, mazmorra, afijos, misiones, mapa,
tablas SQL) no está en este repositorio, que es público.

### Golpe de prueba (solo GOD)

`/nocthold golpe <jugador>` (o sin nombre, para ti) activa o quita el golpe de prueba: ese
jugador mata de un golpe a los monstruos de Nocthold y a los jefes les quita un 25 % por
golpe (4 golpes, para ver sus fases). No cambia ningún objeto ni a ningún otro monstruo y
se borra al reiniciar el servidor.

## Cómo se usa

Producción **no** usa esta carpeta: sigue con `data-otservbr-global`.

Para arrancar un servidor con ella hay que poner en el `.env` de esa instancia:

```
DATA_PACK=data-nocthold
MAP_NAME=canary
```

El mapa es de momento el pequeño de ejemplo de `data-canary` (`canary.otbm`).
Nunca apuntes un servidor con `data-nocthold` a la base de datos de producción:
los datapacks tienen sus propias migraciones.

GitHub Actions ya lo comprueba en cada PR que toca el servidor (paso
"Datapack propio" del workflow *Servidor*): arranca con este datapack y exige
ver `[NOCTHOLD] OK Contenido propio 1.0.0-alpha.1 cargado: 7/7 monstruos, 5/5 NPC, 30/30 hechizos.` sin errores en
nuestros archivos.

Además, en ese mismo arranque se activa `scripts/nocthold/selftest.lua` (solo con
`NOCTHOLD_SELFTEST=1`, que pone GitHub Actions; en pruebas y producción no hace nada).
Dentro del servidor real comprueba las constantes que usamos, los 30 hechizos por nombre y
palabras, que solo existe el comando de GOD, la sala casilla a casilla, los 5 NPC, el portal
del templo, el altar, la barrera y los portales, una piedra-llave de verdad, crea los 7
monstruos y juega una llave 7 entera empezada desde el altar (6 fases, afijos, refuerzos,
portal final, salida y limpieza). Tiene que terminar en `[NOCTHOLD-TEST] TODO OK`. Lanzar hechizos, hablar con
NPC y las fases de los jefes por vida necesitan un jugador conectado: eso lo prueban
`tests/lua/test_nocthold_*.lua` con funciones simuladas y, al final, la prueba en el juego.

## Pendiente (siguiente trabajo)

- Experiencia de los monstruos, botín de verdad y aspectos (lookType) e IDs a partir de los assets del cliente 15.25.
- Ajustar el daño y la curación de los 30 hechizos jugando.
- Mazmorra instanciada (varios grupos a la vez), escalado de vida y daño por llave, y guardar llaves y ranking en la base de datos.
- Mapa propio `.otbm`: ya hay un generador de planos de letras (`tools/mapas/`, ver su README); falta dibujar la mazmorra de verdad, decorarla en el RME y que el script la use en vez de la sala generada al arrancar.
- Talentos, equipo y misiones: solo existen en el diseño.
- Acentos y ñ: los textos para el jugador pasan por `Nocthold.latin1()` (el cliente lee Latin-1). Úsalo en todo texto nuevo con tildes.
