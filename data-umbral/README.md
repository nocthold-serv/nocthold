# data-umbral: datapack propio (en pruebas)

Contenido propio del proyecto, empezando por el paquete **UMBRAL v0.2.0**.

Esta carpeta **no es un datapack completo**: solo lleva nuestros archivos. Al
construir la imagen Docker se copia `data-canary` a `/canary/data-umbral` y se
ponen estos archivos encima (ver `docker/Dockerfile.x86`). Así, cuando Canary
se actualice, no hay que fusionar una copia entera de `data-canary`.

## Qué hay

| Carpeta | Qué es | Estado |
|---|---|---|
| `monster/umbral/` | 7 monstruos (4 normales y 3 jefes) | Se cargan. Aspecto provisional, sin botín ni experiencia, jefes sin fases. |
| `npc/umbral_npcs.lua` | 5 NPC con diálogo básico | Se cargan, pero aún no están colocados en ningún mapa. |
| `scripts/lib/umbral.lua` | Lista de lo que debe cargarse | Lo usan el aviso de arranque y `/umbral status`. |
| `scripts/umbral/umbral_startup.lua` | Al arrancar escribe `[UMBRAL] OK ...` en el log | La comprobación de GitHub busca esa línea. |
| `scripts/umbral/umbral_admin.lua` | Comando `/umbral` y `/umbral status` (solo god) | Solo lee; no cambia nada. |

El diseño (GDD, magias, talentos, objetos, mazmorra, afijos, misiones, mapa,
tablas SQL) no está en este repositorio, que es público.

## Cómo se usa

Producción **no** usa esta carpeta: sigue con `data-otservbr-global`.

Para arrancar un servidor con ella hay que poner en el `.env` de esa instancia:

```
DATA_PACK=data-umbral
MAP_NAME=canary
```

El mapa es de momento el pequeño de ejemplo de `data-canary` (`canary.otbm`).
Nunca apuntes un servidor con `data-umbral` a la base de datos de producción:
los datapacks tienen sus propias migraciones.

GitHub Actions ya lo comprueba en cada PR que toca el servidor (paso
"Datapack UMBRAL" del workflow *Servidor*): arranca con este datapack y exige
ver `[UMBRAL] OK UMBRAL 0.2.0 cargado: 7/7 monstruos, 5/5 NPC.` sin errores en
nuestros archivos.

## Pendiente (siguiente trabajo)

- Convertir las 30 magias diseñadas en hechizos reales, una a una.
- Fases y avisos de los jefes; botín y experiencia de los monstruos.
- Elegir aspectos (lookType) e IDs de objetos a partir de los assets del cliente 15.25.
- Mapa propio `.otbm` en RME y colocar los NPC.
- Mazmorras Mythic+ (instancias, llaves, temporizador, recompensas).
- Revisar en el cliente cómo se ven los acentos y la ñ en nombres y diálogos.
