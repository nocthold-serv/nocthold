# Cliente de Nocthold

Los jugadores entran con **OTClient Redemption** ([opentibiabr/otclient](https://github.com/opentibiabr/otclient), licencia MIT) ya configurado para nuestro servidor. Descomprimen un `.zip`, abren `Nocthold.exe`, ponen su correo y contraseña y juegan. No ven campos de IP, puerto ni versión, y no tienen que instalar nada más.

Por qué OTClient y no el cliente oficial de Tibia: el oficial no se puede redistribuir ni modificar (ver #101), y las mazmorras necesitan interfaz propia (temporizador, % de fuerzas, afijos: #78, #81), que en OTClient se hace con módulos Lua.

## Cómo funciona

| Pieza | Dónde |
|---|---|
| Versión de OTClient que usamos (commit fijo) | [`otclient.ref`](otclient.ref) |
| Lo que cambiamos al cliente (servidor, nombre) | [`configurar.py`](configurar.py) |
| Instrucciones que van dentro del `.zip` | [`LEEME.txt`](LEEME.txt) |
| Compilación y empaquetado | [`.github/workflows/cliente-windows.yml`](../.github/workflows/cliente-windows.yml) |

El workflow compila OTClient para Windows en GitHub Actions y saca dos `.zip`:

- **Nocthold-Windows.zip**: producción, login en `http://158.220.91.85:8088/login`.
- **Nocthold-Pruebas-Windows.zip**: instancia de pruebas, login en `http://158.220.91.85:8188/login` (solo testers).

Los dos usan el protocolo 15.25, que es el que acepta la imagen de Canary del VPS (su log lo dice al arrancar: "Allowed client protocols: 15.25..."). Si cambiamos de imagen, hay que revisar `PROTOCOLO` en `configurar.py`.

**Gráficos del juego.** El `.zip` no lleva los gráficos (sprites, appearances): los descarga el propio cliente la primera vez que el jugador pulsa Login, desde [dudantas/tibia-client](https://github.com/dudantas/tibia-client) (la etiqueta de la versión 15.25, comprobando el SHA-256 de cada fichero). Así nuestro repo no aloja ficheros de Tibia. Cuando tengamos gráficos propios (fase 14) se cambia en `init.lua` (`Services.clientAssets`).

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

## Cuentas de jugador

Mientras la web no sea pública (#26), las cuentas se crean en el VPS:

```
cd ~/nocthold/infra/canary
./nocthold.sh prod cuenta correo@ejemplo.com "Nombre Personaje" knight
```

Vocaciones: `knight`, `paladin`, `sorcerer`, `druid`, `monk` (por defecto knight). El personaje se copia del "Sample" de esa vocación (nivel 8, en el templo). El script genera la contraseña y la enseña una sola vez: pásasela al jugador por privado.

## Actualizar OTClient

Cambia el commit de `otclient.ref`, abre un PR y espera a que **Cliente Windows** salga en verde. Si OTClient cambia `init.lua` y `configurar.py` ya no encuentra lo que busca, el workflow falla en vez de sacar un cliente mal configurado.

## Pendiente

- Firmar el `.exe` (ahora Windows avisa con "Windows protegió su PC").
- Actualizador automático del cliente (`Services.updater`).
- Logo e icono propios.
- Versión para Mac/Linux si hace falta.
