# Canary en el VPS: instancias, copias y despliegue

Dos instancias independientes en el mismo VPS, cada una con su propia base de
datos:

| | Producción (`prod`) | Pruebas (`test`) |
|---|---|---|
| Nombre en el cliente | Nocthold | Nocthold Pruebas |
| Login / juego / estado | 7171 / 7172 / 7173 | 7271 / 7272 / 7273 |
| Login web del cliente | `http://158.220.91.85:8088/login` | `http://158.220.91.85:8188/login` |
| Web MyAAC (solo por túnel) | `http://localhost:8080` | `http://localhost:8180` |
| Base de datos | `nocthold_prod` | `nocthold_test` |

Cada instancia lleva cuatro contenedores: MariaDB, el servidor Canary, el
login (`opentibiabr/login-server`, que da la lista de personajes al cliente) y
la web MyAAC.

**Seguridad.** Docker se salta ufw: cualquier puerto publicado queda abierto.
Por eso MariaDB (3306) no se publica nunca y MyAAC solo escucha dentro del VPS.
Como nadie de fuera llega a la web, nadie puede registrarse: las cuentas las
creamos nosotros (issue #26). Tampoco se crean las cuentas de prueba de Canary
(todas tienen la contraseña `test`).

**Imagen del servidor.** Cada instancia usa la imagen que diga `CANARY_IMAGE`
en su `.env`. La nuestra la construye GitHub Actions desde el repositorio:
`ghcr.io/nocthold-serv/nocthold:develop` para pruebas y `:prod` para
producción (ver [Despliegue automático](#despliegue-automático-fase-3)).
Producción arrancó con la oficial de Canary 3.6.1 y sigue con ella hasta que se
cambie a mano (paso 4 de ese apartado).

## 1. Entrar al VPS y bajar el repositorio

En PowerShell:

```powershell
ssh nocthold@158.220.91.85
```

Ya dentro del VPS (solo la primera vez):

```bash
git clone --depth 1 --branch develop https://github.com/nocthold-serv/nocthold.git ~/nocthold
cd ~/nocthold/infra/canary
```

## 2. Arrancar producción

```bash
./nocthold.sh prod up
```

La primera vez:

- crea `prod.env` con contraseñas aleatorias,
- descarga MariaDB, Canary y el login, y construye la web MyAAC (unos minutos),
- al arrancar, Canary descarga el mapa global.

Mira el log hasta que el servidor diga que está online (Ctrl+C para salir del
log, el servidor sigue funcionando):

```bash
./nocthold.sh prod logs
```

## 3. Arrancar pruebas

Pruebas usa nuestra imagen (`:develop`), así que antes tiene que estar hecho el
paso 1 de [Despliegue automático](#despliegue-automático-fase-3).

```bash
./nocthold.sh test up
./nocthold.sh test logs
./nocthold.sh test clave-god
```

La última orden cambia la contraseña de la cuenta `god` (administrador), que
viene de serie con la contraseña `god`. Guarda la nueva en Bitwarden.

## 4. Guardar las contraseñas

```bash
cat prod.env test.env
```

Copia en Bitwarden las líneas `DB_PASSWORD`, `DB_ROOT_PASSWORD` y
`MYAAC_ADMIN_PASSWORD` de cada una. Estos ficheros no se suben nunca a Git.

## 5. Medir la RAM (issue #22)

Con las dos instancias ya online:

```bash
./nocthold.sh prod ram
./nocthold.sh test ram
free -h
```

## 6. Entrar a la web MyAAC

Desde PowerShell en tu PC, abre un túnel y deja la ventana abierta:

```powershell
ssh -L 8080:localhost:8080 -L 8180:localhost:8180 nocthold@158.220.91.85
```

Luego en el navegador: <http://localhost:8080> (producción) o
<http://localhost:8180> (pruebas). La cuenta de administrador es `admin` (o el
correo `team.nocthold@gmail.com`) con la `MYAAC_ADMIN_PASSWORD` del `.env`.
Desde ahí también se pueden crear cuentas, pero lo más rápido es la orden
`cuenta` (crea cuenta y personaje y te enseña la contraseña generada):

```bash
./nocthold.sh prod cuenta correo@ejemplo.com "Nombre Personaje" knight
```

Vocaciones: `knight` (por defecto), `paladin`, `sorcerer`, `druid` y `monk`.
El jugador entra con el cliente de [`client/`](../../client/README.md).

## Órdenes del día a día

Siempre desde `~/nocthold/infra/canary`:

| Qué | Orden |
|---|---|
| Arrancar o aplicar cambios | `./nocthold.sh prod up` |
| Ver el log | `./nocthold.sh prod logs` |
| Estado | `./nocthold.sh prod ps` |
| Reiniciar solo el servidor | `./nocthold.sh prod restart server` |
| Parar (sin borrar nada) | `./nocthold.sh prod stop` |
| Copia de la base de datos | `./nocthold.sh prod backup` (queda en `~/copias/prod`) |
| Comprobar que la última copia se restaura | `./nocthold.sh prod probar-copia` |
| Qué versión está corriendo | `./nocthold.sh prod version` |
| Aplicar ya lo último de GitHub | `./nocthold.sh prod actualizar` |
| Volver a la versión anterior | `./nocthold.sh prod volver` |

Cambia `prod` por `test` para la instancia de pruebas. Al parar, Canary tiene
hasta 2 minutos para guardar a los jugadores.

## Mapas privados (solo pruebas)

Las mazmorras propias no se suben a GitHub, porque el repositorio es público.
Viven en el VPS, en `~/nocthold-privado/mapas` (fuera del repositorio), y solo
las ve la instancia de pruebas con el datapack `data-nocthold`
(`docker-compose.privado.yml` monta esa carpeta y el arranque copia su contenido
al datapack).

Se suben como un paquete `.tar.gz` con los `.otbm`, `.xml` y el
`nocthold_mapas_privados.lua` que hace `tools/mapas/generar_mapa.py --salida`:

```powershell
scp $HOME\Downloads\mapas_privados.tar.gz nocthold@158.220.91.85:~/
```

y en el VPS:

```bash
cd ~/nocthold/infra/canary
./nocthold.sh test mapas ~/mapas_privados.tar.gz
```

Sustituye los mapas privados que hubiera, reinicia pruebas y dice qué ha cargado.
`./nocthold.sh test mapas` sin fichero dice cuáles hay. Cada mapa tiene su portal
en su hueco del mapa del mundo (`entrada_mundo:` en el plano) o, si no, junto al
templo de la ciudad 1.

### Mapa principal propio (el mapa del mundo)

El paquete también puede traer el mapa principal (por ejemplo `nocthold_world.otbm`
con sus `nocthold_world-monster/-npc/-house/-zones.xml`). El arranque lo pone en
`world/` en vez de `world/custom/` cuando se llama como `MAP_NAME`. Para usarlo:

```bash
./nocthold.sh test mundo nocthold_world   # cambia MAP_NAME en test.env y reinicia
./nocthold.sh test mundo                  # dice cuál hay
./nocthold.sh test mundo canary           # vuelve al mapa de Canary
```

Si falta el `.otbm`, el arranque avisa y usa el mapa de Canary (no baja el de
`MAP_URL`). La Forja Caída pone su portal en el punto `DUNGEON_FALLEN_FORGE` si el
mapa lo tiene. Producción no cambia: sigue con su mapa de siempre.

Además, cada vez que arranca, el servidor deja una copia de su base de datos
dentro del volumen `server-data`.

## Copias de seguridad en Google Drive (issue #24)

Cada noche `copia-diaria.sh` copia la base de datos de cada instancia en marcha,
la sube a la carpeta `nocthold-copias` del Drive de `team.nocthold@gmail.com` y
borra las viejas (se guardan 7 días en el VPS y 30 en Drive). Los domingos,
además, restaura la última copia de producción en una base de datos aparte para
comprobar que sirve. Esa prueba no toca el servidor real.

Se prepara una sola vez:

**1. En el VPS**, instala rclone y trae los scripts nuevos:

```bash
sudo apt install -y rclone
cd ~/nocthold && git pull
```

**2. En tu PC**, en PowerShell, instala rclone y conéctalo a Drive:

```powershell
winget install Rclone.Rclone
```

Cierra PowerShell, ábrela de nuevo y ejecuta:

```powershell
rclone config create gdrive drive scope=drive.file
```

Se abre el navegador: entra con `team.nocthold@gmail.com` y acepta. Con
`drive.file`, rclone solo ve los archivos que crea él, no el resto del Drive.

**3. Pasa esa conexión al VPS** (desde la misma PowerShell):

```powershell
ssh nocthold@158.220.91.85 "mkdir -p ~/.config/rclone"
scp $env:APPDATA\rclone\rclone.conf nocthold@158.220.91.85:.config/rclone/rclone.conf
```

**4. En el VPS**, prueba una copia a mano:

```bash
~/nocthold/infra/canary/copia-diaria.sh
~/nocthold/infra/canary/nocthold.sh prod probar-copia
```

La primera debe acabar con "Todo correcto" y en Drive debe aparecer la carpeta
`nocthold-copias/prod`. La segunda muestra cuántas cuentas y personajes tiene la
copia y acaba con "Restauración correcta".

**5. Prográmala** para todas las noches a las 4:30 (hora del VPS):

```bash
(crontab -l 2>/dev/null; echo '30 4 * * * $HOME/nocthold/infra/canary/copia-diaria.sh >> $HOME/copias/copia-diaria.log 2>&1') | crontab -
crontab -l
```

El resultado de cada noche queda en `~/copias/copia-diaria.log`.

### Restaurar de verdad

Solo si se ha perdido la base de datos. Primero se para el servidor para que no
escriba encima:

```bash
cd ~/nocthold/infra/canary
./nocthold.sh prod stop server
gunzip -c ~/copias/prod/FICHERO.sql.gz | ./nocthold.sh prod exec -T db sh -c 'mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"'
./nocthold.sh prod up
```

Si la copia solo está en Drive, bájala antes con
`rclone copy gdrive:nocthold-copias/prod/FICHERO.sql.gz ~/copias/prod/`.

**Nunca uses `down -v`** en producción: borra la base de datos.

## Despliegue automático (fase 3)

### Cómo llega un cambio al servidor

1. **PR a `develop`.** GitHub Actions pasa el workflow **Servidor**: comprueba
   la sintaxis de todos los `.lua`, los tests Lua y los scripts; compila la
   imagen Docker; la arranca con MariaDB y este mismo `docker-compose.yml`;
   espera a "server online!" y prueba un login real. Si algo falla, el PR sale
   en rojo y no se puede fusionar.
2. **Fusionar en `develop`.** Actions vuelve a compilar y sube la imagen
   `ghcr.io/nocthold-serv/nocthold:develop`. La instancia de **pruebas** mira
   cada 5 minutos si hay imagen nueva y, si la hay, se reinicia con ella.
   Desde que fusionas hasta que está en pruebas pasan unos 20-30 minutos (lo
   que tarda en compilar).
3. **Pasar a producción.** PR de `develop` a `main` y de `main` a `prod`. Al
   fusionar en `prod` se sube `:prod`. **Producción** no se reinicia en mitad
   del día: lo aplica a las **6:01**, justo después del server save de las
   6:00 (Canary avisa a los jugadores 5 minutos antes y se reinicia). Antes de
   cambiar de versión hace una copia de la base de datos en `~/copias/prod`.
   Al fusionar en `prod`, GitHub también publica las **novedades para los
   jugadores**: junta el apartado "Para los jugadores" de cada PR nuevo y crea
   una Release "Novedades del <día>" en
   <https://github.com/nocthold-serv/nocthold/releases>, lista para copiar en
   Discord. Por eso ese apartado del PR se escribe en lenguaje de jugador.
4. **Si la versión nueva no arranca** en 10 minutos, la instancia vuelve sola a
   la anterior y espera a la siguiente versión que llegue de GitHub.

Además de la imagen, cada actualización baja los scripts y el
`docker-compose.yml` de la rama en la que está el repositorio del VPS
(`develop`). No toques ficheros del repositorio a mano en el VPS: si hay
cambios locales, la actualización no puede traer los nuevos (lo avisa en el
log). Los `.env` no cuentan, esos no están en Git.

Cada imagen se sube también con el commit (`:sha-abc1234`), que es lo que
permite volver a una versión concreta.

### Puesta en marcha (una sola vez)

**1. Hacer pública la imagen.** El primer push a `develop` después de fusionar
este cambio crea el paquete `nocthold` en GitHub, privado. Como el repositorio
ya es público, lo más sencillo es que la imagen también lo sea (así el VPS la
baja sin contraseña):

- Abre <https://github.com/orgs/nocthold-serv/packages/container/nocthold/settings>
  (o: organización → **Packages** → **nocthold** → **Package settings**).
- Abajo del todo, en **Danger Zone**, pulsa **Change visibility**, elige
  **Public** y escribe `nocthold` para confirmar.

**2. En el VPS**, trae los scripts nuevos:

```bash
cd ~/nocthold && git pull
cd infra/canary
```

**3. Pruebas.** Arráncala (apartado 3 de arriba) y activa su actualización
automática:

```bash
./nocthold.sh test up
./nocthold.sh test clave-god
./nocthold.sh test auto
```

En UptimeRobot añade los monitores de los puertos 7271 y 8188.

**4. Producción.** Solo cuando la rama `prod` tenga ya su imagen y la hayáis
probado en pruebas. Cambia la imagen en `prod.env`, aplícala a una hora
tranquila y activa la actualización diaria:

```bash
sed -i 's#^CANARY_IMAGE=.*#CANARY_IMAGE=ghcr.io/nocthold-serv/nocthold:prod#' prod.env
./nocthold.sh prod actualizar
./nocthold.sh prod auto
```

Ojo: producción se creó con la imagen oficial 3.6.1. Al pasar a la nuestra,
Canary puede actualizar las tablas de la base de datos. La copia se hace sola
antes, pero volver a la oficial después puede pedir restaurar esa copia
([Restaurar de verdad](#restaurar-de-verdad)).

### Ver qué está pasando

```bash
./nocthold.sh prod version     # imagen, commit y desde cuándo
./nocthold.sh prod auto ver    # próxima actualización y log de las últimas
./nocthold.sh test auto ver
```

Para quitar la actualización automática: `./nocthold.sh prod auto quitar`.

### Volver atrás

**Rápido, en el VPS** (un minuto):

```bash
./nocthold.sh prod volver            # a la versión que había antes
./nocthold.sh prod volver abc1234    # o a un commit concreto de develop/prod
```

La instancia queda **fijada** en esa versión: la actualización automática no la
toca hasta que digas lo contrario. En producción hace antes una copia de la
base de datos.

**Después, en GitHub**, deshaz el cambio malo para que no vuelva a entrar: en
la página del PR que lo metió pulsa **Revert** (abajo, junto a "merged"). Eso
crea un PR nuevo que lo deshace; fusiónalo en la rama que toque. Cuando la
imagen arreglada esté subida, suelta la instancia:

```bash
./nocthold.sh prod soltar
./nocthold.sh prod actualizar   # para aplicarla ya; si no, a las 6:01
```

**Si el cambio malo tocó la base de datos** (personajes, tablas nuevas…),
volver a la imagen anterior no basta: restaura la copia hecha justo antes de la
actualización. Está en `~/copias/prod` con la fecha y hora de esa mañana (ver
[Restaurar de verdad](#restaurar-de-verdad)).
