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
| `npc/nocthold_npcs.lua` | 5 NPC con diálogo | Se colocan solos al generar la mazmorra. |
| `scripts/nocthold/spells/` | 30 hechizos: Guardian (knight), Warden (druid) y Arcanist (sorcerer) | Se lanzan con `nocthold <palabra>` (lista: `/nocthold spells`). Balance sin ajustar. |
| `scripts/nocthold/runtime/` | La Forja Caída: 6 encuentros, llaves 0-10, cronómetro y recompensa en oro | Una sola arena compartida (un grupo a la vez); el estado se pierde al reiniciar. |
| `scripts/lib/nocthold.lua` | Lista de lo que debe cargarse y `Nocthold.latin1()` | Lo usan el aviso de arranque y `/nocthold status`. |
| `scripts/nocthold/nocthold_startup.lua` | Al arrancar escribe `[NOCTHOLD] OK ...` en el log | La comprobación de GitHub busca esa línea. |
| `scripts/nocthold/nocthold_admin.lua` | `/nocthold status` y `/nocthold spells` (solo god) | Solo lee. |

### Probar la mazmorra

1. Con un god, ponte encima de una casilla normal y escribe `!nocthold buildmap`. Genera la mazmorra en X=64000, Y=64000, Z=7 copiando el suelo que pisas, y coloca los 5 NPC. Hay que repetirlo después de cada reinicio del servidor.
2. El líder del grupo (1 a 5 jugadores, a menos de 12 casillas): `!nocthold key 0` (de 0 a 10), `!nocthold enter` y `!nocthold start`.
3. `!nocthold status` muestra la fase y el tiempo; `!nocthold leave` te devuelve donde estabas; `!nocthold reset` (god) lo reinicia todo.
4. Desde la llave 4 sale un Sabueso más en cada grupo; desde la 7, un Coloso más con el jefe final.

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
palabras, los comandos, la sala de `buildmap` casilla a casilla, los 5 NPC, crea los 7
monstruos y juega una llave 7 entera (6 fases, afijos, refuerzos, llave a 8, salida y
limpieza). Tiene que terminar en `[NOCTHOLD-TEST] TODO OK`. Lanzar hechizos, hablar con
NPC y las fases de los jefes por vida necesitan un jugador conectado: eso lo prueban
`tests/lua/test_nocthold_*.lua` con funciones simuladas y, al final, la prueba en el juego.

## Pendiente (siguiente trabajo)

- Experiencia de los monstruos, botín de verdad y aspectos (lookType) e IDs a partir de los assets del cliente 15.25.
- Ajustar el daño y la curación de los 30 hechizos jugando.
- Mazmorra instanciada (varios grupos a la vez), escalado de vida y daño por llave, y guardar llaves y ranking en la base de datos.
- Mapa propio `.otbm` en RME (ahora la mazmorra es una sala generada al vuelo).
- Talentos, equipo y misiones: solo existen en el diseño.
- Acentos y ñ: los textos para el jugador pasan por `Nocthold.latin1()` (el cliente lee Latin-1). Úsalo en todo texto nuevo con tildes.
