# Levantar Canary en el VPS (fase 2)

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

**De momento** las dos instancias usan la imagen oficial de Canary 3.6.1, con
su datapack y su mapa global. En la fase 3 cada una pasará a usar nuestra propia
imagen (pruebas desde `develop`, producción desde `prod`): solo hay que cambiar
`CANARY_IMAGE` en el `.env`.

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

```bash
./nocthold.sh test up
./nocthold.sh test logs
```

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
Desde ahí se crean las cuentas de los testers.

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

Cambia `prod` por `test` para la instancia de pruebas. Al parar, Canary tiene
hasta 2 minutos para guardar a los jugadores.

Además, cada vez que arranca, el servidor deja una copia de su base de datos
dentro del volumen `server-data`. Las copias diarias fuera del VPS van en el
issue #24.

**Nunca uses `down -v`** en producción: borra la base de datos.
