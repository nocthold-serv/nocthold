# data-nocthold: datapack propio (en pruebas)

Contenido propio del proyecto, empezando por el primer paquete del compañero (v0.2.0, que venía con el nombre provisional "UMBRAL"; el juego se llama Nocthold).

Esta carpeta **no es un datapack completo**: solo lleva nuestros archivos. Al
construir la imagen Docker se copia `data-canary` a `/canary/data-nocthold` y se
ponen estos archivos encima (ver `docker/Dockerfile.x86`). Así, cuando Canary
se actualice, no hay que fusionar una copia entera de `data-canary`.

## Qué hay

| Carpeta | Qué es | Estado |
|---|---|---|
| `monster/nocthold/` | 7 monstruos (4 normales y 3 jefes) | Se cargan. Aspecto provisional, sin botín ni experiencia, jefes sin fases. |
| `npc/nocthold_npcs.lua` | 5 NPC con diálogo básico | Se cargan, pero aún no están colocados en ningún mapa. |
| `scripts/lib/nocthold.lua` | Lista de lo que debe cargarse | Lo usan el aviso de arranque y `/nocthold status`. |
| `scripts/nocthold/nocthold_startup.lua` | Al arrancar escribe `[NOCTHOLD] OK ...` en el log | La comprobación de GitHub busca esa línea. |
| `scripts/nocthold/nocthold_admin.lua` | Comando `/nocthold` y `/nocthold status` (solo god) | Solo lee; no cambia nada. |

El diseño (GDD, magias, talentos, objetos, mazmorra, afijos, misiones, mapa,
tablas SQL) no está en este repositorio, que es público.

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
ver `[NOCTHOLD] OK Contenido propio 0.2.1 cargado: 7/7 monstruos, 5/5 NPC.` sin errores en
nuestros archivos.

## Pendiente (siguiente trabajo)

- Convertir las 30 magias diseñadas en hechizos reales, una a una.
- Fases y avisos de los jefes; botín y experiencia de los monstruos.
- Elegir aspectos (lookType) e IDs de objetos a partir de los assets del cliente 15.25.
- Mapa propio `.otbm` en RME y colocar los NPC.
- Mazmorras Mythic+ (instancias, llaves, temporizador, recompensas).
- Acentos y ñ: los textos para el jugador pasan por `Nocthold.latin1()` (el cliente lee Latin-1). Úsalo en todo texto nuevo con tildes.
