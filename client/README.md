# Cliente de Nocthold

Los jugadores entran con **OTClient Redemption** ([opentibiabr/otclient](https://github.com/opentibiabr/otclient), licencia MIT) ya configurado para nuestro servidor. Descomprimen un `.zip`, abren `Nocthold.exe`, ponen su correo y contraseña y juegan. No ven campos de IP, puerto ni versión, y no tienen que instalar nada más.

Por qué OTClient y no el cliente oficial de Tibia: el oficial no se puede redistribuir ni modificar (ver #101), y las mazmorras necesitan interfaz propia (temporizador, % de fuerzas, afijos: #78, #81), que en OTClient se hace con módulos Lua.

## Cómo funciona

| Pieza | Dónde |
|---|---|
| Versión de OTClient que usamos (commit fijo) | [`otclient.ref`](otclient.ref) |
| Lo que cambiamos al cliente (servidor, nombre, hechizos) | [`configurar.py`](configurar.py) |
| Hechizos: iconos y descripciones propios | [`hechizos/`](hechizos/LEEME.md) |
| Release de la que se reutiliza el `.exe` (vacío = compilar) | [`exe.ref`](exe.ref) |
| Actualizador automático y su lista de ficheros | [`actualizador/updater.lua`](actualizador/updater.lua), [`manifiesto.py`](manifiesto.py) |
| Instrucciones que van dentro del `.zip` | [`LEEME.txt`](LEEME.txt) |
| Compilación y empaquetado | [`.github/workflows/cliente-windows.yml`](../.github/workflows/cliente-windows.yml) |

El workflow compila OTClient para Windows en GitHub Actions y saca dos `.zip`:

- **Nocthold-Windows.zip**: producción, login en `http://158.220.91.85:8088/login`.
- **Nocthold-Pruebas-Windows.zip**: instancia de pruebas, login en `http://158.220.91.85:8188/login` (solo testers).

Los dos usan el protocolo 15.25, que es el que acepta la imagen de Canary del VPS (su log lo dice al arrancar: "Allowed client protocols: 15.25..."). Si cambiamos de imagen, hay que revisar `PROTOCOLO` en `configurar.py`.

**Gráficos del juego.** El `.zip` no lleva los gráficos (sprites, appearances): los descarga el propio cliente la primera vez que el jugador pulsa Login y los guarda en `%APPDATA%\nocthold\nocthold\`, fuera de la carpeta del cliente, para que una versión nueva del `.zip` no los vuelva a pedir, desde [dudantas/tibia-client](https://github.com/dudantas/tibia-client) (la etiqueta de la versión 15.25, comprobando el SHA-256 de cada fichero). Así nuestro repo no aloja ficheros de Tibia. Cuando tengamos gráficos propios (fase 14) se cambia en `init.lua` (`Services.clientAssets`).

## Sacar una versión para los jugadores

1. Que el último run de **Cliente Windows** en [Actions](https://github.com/nocthold-serv/nocthold/actions/workflows/cliente-windows.yml) esté en verde.
2. Ir a [Releases > Draft a new release](https://github.com/nocthold-serv/nocthold/releases/new), en "Choose a tag" escribir `cliente-v0.1.0` (o el número que toque), elegir la rama `develop` como destino y pulsar **Publish release**. Desde el PC también vale:
   ```
   git checkout develop
   git pull
   git tag cliente-v0.1.0
   git push origin cliente-v0.1.0
   ```
3. El workflow compila (unos minutos, o ~1 h la primera vez) y añade los dos `.zip` a la release. El enlace que se da a los jugadores es el de la última release:
   https://github.com/nocthold-serv/nocthold/releases/latest

Para probar sin publicar nada: Actions > Cliente Windows > Run workflow, y al terminar se descarga el artifact `cliente-windows` desde la página del run.

## Actualizaciones automáticas

Desde la 0.1.3 el jugador no tiene que volver a descargar el `.zip` cuando cambiamos algo del cliente (hechizos, iconos, textos, módulos). Al abrir `Nocthold.exe`:

1. El cliente lee la lista de ficheros de su canal: `nocthold/lista.json` (normal) o `nocthold-pruebas/lista.json` (pruebas) de la rama [`cliente-actualizaciones`](https://github.com/nocthold-serv/nocthold/tree/cliente-actualizaciones).
2. Compara la huella (crc32) de cada fichero con la del suyo y descarga solo los que han cambiado o son nuevos.
3. Los guarda en su carpeta y se reinicia solo. Si no ha cambiado nada, arranca directamente.

Si no hay internet o GitHub no contesta, el cliente arranca con lo que tiene (lo apunta en el `.log`). Si una actualización no se queda bien instalada, no lo vuelve a intentar en bucle con esa misma versión.

Quién publica cada canal (lo hace solo el workflow, job "Publicar actualización automática"):

- **Normal**: al crear una etiqueta `cliente-vX.Y.Z` (la misma release de siempre). Los jugadores reciben los cambios la próxima vez que abran el juego.
- **Pruebas**: en cada push a `develop` que toque el cliente o los hechizos.

Límites:

- **El `.exe` nunca se actualiza solo**: sin firmar, Windows bloquearía uno nuevo. Si algún día hay que cambiarlo (nueva versión de OTClient), los jugadores descargan el `.zip` otra vez.
- **Un fichero que quitemos del cliente no se borra** de los clientes ya instalados (solo se añaden o cambian ficheros).
- Los `.zip` anteriores a la 0.1.3 no traen el actualizador: esos jugadores tienen que descargar la 0.1.3 una vez.

## Cuentas de jugador

Mientras la web no sea pública (#26), las cuentas se crean en el VPS:

```
cd ~/nocthold/infra/canary
./nocthold.sh prod cuenta correo@ejemplo.com "Nombre Personaje" knight
```

Vocaciones: `knight`, `paladin`, `sorcerer`, `druid`, `monk` (por defecto knight). El personaje se copia del "Sample" de esa vocación (nivel 8, en el templo). El script genera la contraseña y la enseña una sola vez: pásasela al jugador por privado.

**Siempre el mismo `.exe`.** Como el `.exe` no está firmado, Windows (Smart App Control y SmartScreen) bloquea o avisa con cada `.exe` nuevo que no ha visto antes. Por eso el workflow no compila: reutiliza el `.exe` de la release indicada en [`exe.ref`](exe.ref) y solo cambia los ficheros de alrededor. Cuando firmemos el `.exe` ya no hará falta.

## Actualizar OTClient

Cambia el commit de `otclient.ref`, vacía `exe.ref` para que se compile un `.exe` nuevo, abre un PR y espera a que **Cliente Windows** salga en verde. Si OTClient cambia `init.lua` y `configurar.py` ya no encuentra lo que busca, el workflow falla en vez de sacar un cliente mal configurado.

## Pendiente

- Firmar el `.exe` (ahora Windows avisa con "Windows protegió su PC").
- Que el actualizador también borre los ficheros que quitemos.
- Logo e icono propios.
- Versión para Mac/Linux si hace falta.
