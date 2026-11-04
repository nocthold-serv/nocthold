#!/usr/bin/env bash
# Manejo de las instancias de Nocthold en el VPS.
#
#   ./nocthold.sh prod up        arranca (o actualiza) producción
#   ./nocthold.sh test up        arranca (o actualiza) pruebas
#   ./nocthold.sh prod logs      sigue el log del servidor (Ctrl+C para salir)
#   ./nocthold.sh prod ps        estado de los contenedores
#   ./nocthold.sh prod ram       RAM y CPU que usa cada contenedor
#   ./nocthold.sh prod backup    copia de la base de datos en ~/copias/prod
#   ./nocthold.sh prod probar-copia   restaura la última copia aparte y la comprueba
#   ./nocthold.sh prod stop      para la instancia (no borra nada)
#   ./nocthold.sh prod cuenta <correo> "<Personaje>" [vocación]
#                                crea una cuenta de jugador con un personaje
#   ./nocthold.sh prod clave-god pone una contraseña nueva a la cuenta god
#   ./nocthold.sh prod version   qué imagen (y qué commit) está corriendo
#   ./nocthold.sh prod actualizar   baja lo último de GitHub y lo aplica si hay algo nuevo
#   ./nocthold.sh prod volver [commit]   vuelve a la versión anterior (o a ese commit)
#   ./nocthold.sh prod soltar    deshace "volver": se vuelve a seguir la rama
#   ./nocthold.sh prod auto [quitar|ver]   actualización automática (prod a las
#                                6:01 tras el server save, test cada 5 minutos)
#   ./nocthold.sh test mapas <fichero.tar.gz>
#                                añade mapas privados (no van a GitHub) a pruebas
#                                y reinicia; los del mismo nombre se cambian, el
#                                resto se queda; sin fichero dice cuáles hay
#   ./nocthold.sh test mapas quitar <nombre>   quita un mapa privado
#   ./nocthold.sh test mundo <nombre|canary>
#                                mapa principal de pruebas: uno privado (<nombre>.otbm del
#                                paquete de mapas) o el de Canary; sin nombre dice cuál hay
#   ./nocthold.sh prod <otro>    cualquier orden de "docker compose"
#
# La primera vez crea prod.env / test.env con contraseñas aleatorias.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

instancia="${1:-}"
orden="${2:-}"
case "$instancia" in
	prod)
		nombre="Nocthold"; login=7171; juego=7172; estado=7173; http=8088; web=8080
		bd=nocthold_prod; gm="GM Nocthold"; rama=prod ;;
	test)
		nombre="Nocthold Pruebas"; login=7271; juego=7272; estado=7273; http=8188; web=8180
		bd=nocthold_test; gm="GM Pruebas"; rama=develop ;;
	*)
		sed -n '2,/^set /{/^set /!p}' "$0" | sed 's/^# \{0,1\}//'
		exit 1 ;;
esac
[ -n "$orden" ] || { echo "Falta la orden. Ejemplo: ./nocthold.sh $instancia up"; exit 1; }

env_file="$instancia.env"
if [ ! -f "$env_file" ]; then
	echo "Creando $env_file con contraseñas nuevas..."
	umask 077
	while IFS= read -r linea; do
		while [[ "$linea" == *"@@RANDOM@@"* ]]; do
			linea="${linea/@@RANDOM@@/$(openssl rand -hex 16)}"
		done
		linea="${linea//@@SERVER_NAME@@/$nombre}"
		linea="${linea//@@LOGIN_PORT@@/$login}"
		linea="${linea//@@GAME_PORT@@/$juego}"
		linea="${linea//@@STATUS_PORT@@/$estado}"
		linea="${linea//@@LOGIN_HTTP_PORT@@/$http}"
		linea="${linea//@@MYAAC_PORT@@/$web}"
		linea="${linea//@@DB_NAME@@/$bd}"
		linea="${linea//@@ADMIN_PLAYER@@/$gm}"
		linea="${linea//@@RAMA@@/$rama}"
		printf '%s\n' "$linea"
	done <instancia.env.example >"$env_file"
	echo "Hecho. Las contraseñas están en $(pwd)/$env_file (guárdalas en Bitwarden)."
fi

leer() { grep -m1 "^$1=" "$env_file" | cut -d= -f2-; }
compose=(docker compose -p "nocthold-$instancia" --env-file "$env_file" -f docker-compose.yml)
# Mapas privados (no están en GitHub): solo en pruebas, en una carpeta del VPS fuera del repositorio.
mapas_privados="$HOME/nocthold-privado/mapas"
if [ "$instancia" = test ]; then
	mkdir -p "$mapas_privados"
	export MAPAS_PRIVADOS="$mapas_privados"
	compose+=(-f docker-compose.privado.yml)
fi
shift 2

# "volver" deja aquí la imagen elegida. Mientras exista, manda sobre la del .env
# y la actualización automática no toca la instancia.
fijada_file="$instancia.fijada"
if [ -f "$fijada_file" ]; then
	CANARY_IMAGE="$(head -1 "$fijada_file")"
	export CANARY_IMAGE
fi
imagen_ghcr="ghcr.io/nocthold-serv/nocthold"
anterior="nocthold-$instancia:anterior"
en_marcha="nocthold-$instancia:en-marcha"

contenedor() { "${compose[@]}" ps -q "$1" 2>/dev/null || true; }

# Espera a que el servidor diga "server online!". Si se cae o no llega en
# 10 minutos, devuelve error.
esperar_online() {
	local id
	for _ in $(seq 1 60); do
		id="$(contenedor server)"
		if [ -n "$id" ] && docker logs "$id" 2>&1 | grep -q "server online!"; then
			echo "Servidor online."
			return 0
		fi
		if [ -n "$id" ] && [ "$(docker inspect -f '{{.RestartCount}}' "$id")" != 0 ]; then
			echo "El servidor se ha caído al arrancar."
			return 1
		fi
		sleep 10
	done
	echo "El servidor no ha dicho 'server online!' en 10 minutos."
	return 1
}

# Pone en marcha la imagen indicada y la deja fijada. Con un segundo argumento
# (la imagen que ha fallado), "actualizar" la suelta sola cuando haya otra nueva.
fijar_y_arrancar() {
	printf '%s\n' "$@" >"$fijada_file"
	CANARY_IMAGE="$1"
	export CANARY_IMAGE
	"${compose[@]}" up -d server
	esperar_online
}

case "$orden" in
	up)
		"${compose[@]}" up -d --build --remove-orphans "$@"
		"${compose[@]}" ps ;;
	stop)
		"${compose[@]}" stop "$@" ;;
	logs)
		"${compose[@]}" logs -f --tail 200 "${@:-server}" ;;
	ram)
		mapfile -t ids < <(docker ps -q --filter "label=com.docker.compose.project=nocthold-$instancia")
		docker stats --no-stream \
			--format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}' \
			"${ids[@]}" ;;
	backup)
		DB_NAME="$(leer DB_NAME)"
		DB_ROOT_PASSWORD="$(leer DB_ROOT_PASSWORD)"
		destino="$HOME/copias/$instancia"
		mkdir -p "$destino"
		fichero="$destino/${DB_NAME}_$(date +%Y-%m-%d_%H%M).sql.gz"
		"${compose[@]}" exec -T -e MYSQL_PWD="$DB_ROOT_PASSWORD" db \
			mariadb-dump -u root --single-transaction --routines --triggers "$DB_NAME" | gzip >"$fichero.tmp"
		mv "$fichero.tmp" "$fichero"
		echo "Copia guardada en $fichero ($(du -h "$fichero" | cut -f1))" ;;
	probar-copia)
		# Restaura una copia en una MariaDB de usar y tirar (no toca la instancia real)
		# y cuenta lo que hay dentro. Sin fichero, usa la copia más reciente.
		fichero="${1:-$(ls -1t "$HOME/copias/$instancia"/*.sql.gz 2>/dev/null | head -1)}"
		[ -f "$fichero" ] || { echo "No encuentro ninguna copia en ~/copias/$instancia"; exit 1; }
		echo "Probando $fichero ..."
		prueba="nocthold-prueba-copia-$$"
		docker run -d --rm --name "$prueba" -e MARIADB_ROOT_PASSWORD=prueba -e MARIADB_DATABASE=prueba \
			mariadb:11.4.13 >/dev/null
		trap 'docker rm -f "$prueba" >/dev/null 2>&1 || true' EXIT
		until docker exec "$prueba" healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; do sleep 2; done
		gunzip -c "$fichero" | docker exec -i -e MYSQL_PWD=prueba "$prueba" mariadb -u root prueba
		docker exec -e MYSQL_PWD=prueba "$prueba" mariadb -u root prueba -e \
			"SELECT (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='prueba') AS tablas,
			        (SELECT COUNT(*) FROM accounts) AS cuentas,
			        (SELECT COUNT(*) FROM players) AS personajes;"
		echo "Restauración correcta." ;;
	cuenta)
		# Mientras no haya registro público (#26) las cuentas se crean aquí.
		correo="${1:-}"; personaje="${2:-}"; vocacion="${3:-knight}"
		if [[ ! "$correo" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] ||
			[[ ! "$personaje" =~ ^[A-Z][a-z]+( [A-Z]?[a-z]+){0,2}$ ]] || [ ${#personaje} -gt 25 ]; then
			echo "Uso: ./nocthold.sh $instancia cuenta <correo> \"<Personaje>\" [knight|paladin|sorcerer|druid|monk]"
			echo "Personaje: solo letras, empieza por mayúscula, hasta 3 palabras y 25 caracteres."
			exit 1
		fi
		case "$vocacion" in
			knight) muestra="Knight Sample" ;; paladin) muestra="Paladin Sample" ;;
			sorcerer) muestra="Sorcerer Sample" ;; druid) muestra="Druid Sample" ;;
			monk) muestra="Monk Sample" ;;
			*) echo "Vocación desconocida: $vocacion"; exit 1 ;;
		esac
		DB_NAME="$(leer DB_NAME)"
		DB_ROOT_PASSWORD="$(leer DB_ROOT_PASSWORD)"
		sql() {
			"${compose[@]}" exec -T -e MYSQL_PWD="$DB_ROOT_PASSWORD" db \
				mariadb -u root -N -B "$DB_NAME" -e "$1"
		}
		[ "$(sql "SELECT COUNT(*) FROM accounts WHERE email = '$correo'")" = 0 ] ||
			{ echo "Ya hay una cuenta con el correo $correo."; exit 1; }
		[ "$(sql "SELECT COUNT(*) FROM players WHERE name = '$personaje'")" = 0 ] ||
			{ echo "Ya existe un personaje llamado $personaje."; exit 1; }
		[ "$(sql "SELECT COUNT(*) FROM players WHERE name = '$muestra'")" = 1 ] ||
			{ echo "No encuentro el personaje de muestra '$muestra' en la base de datos."; exit 1; }
		clave="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-14)"
		# Si algo falla, mariadb corta y la transacción sin COMMIT se deshace.
		sql "START TRANSACTION;
			INSERT INTO accounts (name, email, password, type, creation)
				VALUES ('j$(openssl rand -hex 6)', '$correo', SHA1('$clave'), 1, UNIX_TIMESTAMP());
			SET @cuenta = LAST_INSERT_ID();
			INSERT INTO players (name, group_id, account_id, level, vocation, health, healthmax, experience,
				lookbody, lookfeet, lookhead, looklegs, looktype, maglevel, mana, manamax, manaspent,
				town_id, conditions, cap, sex, skill_club, skill_club_tries, skill_sword, skill_sword_tries,
				skill_axe, skill_axe_tries, skill_dist, skill_dist_tries)
			SELECT '$personaje', 1, @cuenta, level, vocation, health, healthmax, experience,
				lookbody, lookfeet, lookhead, looklegs, looktype, maglevel, mana, manamax, manaspent,
				town_id, '', cap, sex, skill_club, skill_club_tries, skill_sword, skill_sword_tries,
				skill_axe, skill_axe_tries, skill_dist, skill_dist_tries
			FROM players WHERE name = '$muestra';
			COMMIT;"
		echo "Cuenta creada en $nombre."
		echo "  Correo:     $correo"
		echo "  Contraseña: $clave"
		echo "  Personaje:  $personaje ($vocacion)"
		echo "Pásale estos datos al jugador por privado; aquí no se guardan." ;;
	clave-god)
		# schema.sql crea la cuenta 1 (god, de tipo administrador) con la
		# contraseña "god". Hay que cambiarla en cada instancia nueva.
		DB_NAME="$(leer DB_NAME)"
		DB_ROOT_PASSWORD="$(leer DB_ROOT_PASSWORD)"
		clave="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
		"${compose[@]}" exec -T -e MYSQL_PWD="$DB_ROOT_PASSWORD" db \
			mariadb -u root "$DB_NAME" -e "UPDATE accounts SET password = SHA1('$clave') WHERE id = 1;"
		echo "Cuenta god de $nombre: nueva contraseña $clave (guárdala en Bitwarden)." ;;
	version)
		id="$(contenedor server)"
		[ -n "$id" ] || { echo "$nombre no está en marcha."; exit 0; }
		echo "Imagen:  $(docker inspect -f '{{.Config.Image}}' "$id")"
		commit="$(docker inspect -f '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$id")"
		[ -z "$commit" ] || echo "Commit:  $commit  (https://github.com/nocthold-serv/nocthold/commit/$commit)"
		echo "Desde:   $(docker inspect -f '{{.State.StartedAt}}' "$id" | cut -c1-19 | tr T ' ') (UTC)"
		if [ -f "$fijada_file" ] && [ -z "$(sed -n 2p "$fijada_file")" ]; then
			echo "FIJADA con 'volver': no se actualiza sola. Para seguir la rama: ./nocthold.sh $instancia soltar"
		elif [ -f "$fijada_file" ]; then
			echo "En la versión anterior porque la última no arrancaba. Se actualizará sola con la siguiente."
		fi ;;
	actualizar)
		# 1) Scripts y docker-compose: los trae de GitHub y se relanza con la
		#    versión nueva de este mismo script.
		if [ "${1:-}" != "--sin-git" ]; then
			raiz="$(git rev-parse --show-toplevel 2>/dev/null || true)"
			if [ -n "$raiz" ]; then
				rama_repo="$(git -C "$raiz" rev-parse --abbrev-ref HEAD)"
				if git -C "$raiz" fetch -q --depth 1 origin "$rama_repo" &&
					git -C "$raiz" reset -q --keep FETCH_HEAD; then
					:
				else
					echo "Aviso: no he podido actualizar el repositorio (¿cambios a mano en el VPS?). Sigo con la imagen."
				fi
			fi
			exec "$0" "$instancia" actualizar --sin-git
		fi
		echo "===== $(date '+%Y-%m-%d %H:%M') $nombre ====="
		if [ -f "$fijada_file" ]; then
			fallida="$(sed -n 2p "$fijada_file")"
			if [ -z "$fallida" ]; then
				echo "Fijada en $(head -1 "$fijada_file") con 'volver': no se actualiza."
				echo "Para seguir otra vez la rama: ./nocthold.sh $instancia soltar"
				exit 0
			fi
			# Fijada sola porque la última versión no arrancaba: en cuanto GitHub
			# tenga otra distinta, se prueba.
			imagen_rama="$(leer CANARY_IMAGE)"
			docker pull -q "$imagen_rama" >/dev/null
			if [ "$(docker image inspect -f '{{.Id}}' "$imagen_rama")" = "$fallida" ]; then
				echo "La última versión es la que no arrancaba: sigo con la anterior."
				exit 0
			fi
			echo "Hay una versión nueva después de la que fallaba: la pruebo."
			rm -f "$fijada_file"
			CANARY_IMAGE="$imagen_rama"
		fi
		id="$(contenedor server)"
		[ -n "$id" ] || { echo "$nombre no está en marcha: no se actualiza."; exit 0; }
		# 2) Imagen: ¿hay una nueva en GitHub?
		imagen="${CANARY_IMAGE:-$(leer CANARY_IMAGE)}"
		actual="$(docker inspect -f '{{.Image}}' "$id")"
		# Se etiqueta la imagen en marcha antes de bajar la nueva, para que Docker
		# no la borre y se pueda volver a ella.
		docker tag "$actual" "$en_marcha" 2>/dev/null ||
			echo "Aviso: la imagen en marcha ya no está en disco; no se podrá volver a ella con 'volver'."
		docker pull -q "$imagen" >/dev/null
		nueva="$(docker image inspect -f '{{.Id}}' "$imagen")"
		# 3) ¿Ha cambiado algo del docker-compose o del .env?
		cambia_config=no
		while read -r servicio hash; do
			cid="$(contenedor "$servicio")"
			[ -n "$cid" ] || continue
			[ "$(docker inspect -f '{{index .Config.Labels "com.docker.compose.config-hash"}}' "$cid")" = "$hash" ] ||
				cambia_config=si
		done < <("${compose[@]}" config --hash '*')
		if [ "$actual" = "$nueva" ] && [ "$cambia_config" = no ]; then
			echo "Ya está al día."
			exit 0
		fi
		echo "Hay cambios (imagen nueva: $([ "$actual" = "$nueva" ] && echo no || echo sí), configuración: $cambia_config). Aplicando..."
		docker tag "$en_marcha" "$anterior" 2>/dev/null || true
		[ "$instancia" != prod ] || "$0" prod backup
		"${compose[@]}" up -d --remove-orphans
		if esperar_online; then
			"$0" "$instancia" version
			docker image prune -f >/dev/null
			exit 0
		fi
		echo "La versión nueva no arranca: vuelvo a la anterior."
		"${compose[@]}" logs --no-color --tail 80 server || true
		fijar_y_arrancar "$anterior" "$nueva" || true
		echo "Cuando llegue a GitHub una versión arreglada se aplicará sola."
		exit 1 ;;
	volver)
		if [ -n "${1:-}" ]; then
			destino="$imagen_ghcr:sha-${1:0:7}"
			docker pull -q "$destino" >/dev/null ||
				{ echo "No encuentro $destino. ¿Es un commit de develop o prod que pasó por GitHub Actions?"; exit 1; }
		else
			destino="$anterior"
			docker image inspect "$destino" >/dev/null 2>&1 ||
				{ echo "No hay versión anterior guardada. Usa: ./nocthold.sh $instancia volver <commit>"; exit 1; }
		fi
		[ "$instancia" != prod ] || "$0" prod backup
		echo "Volviendo a $destino ..."
		fijar_y_arrancar "$destino"
		"$0" "$instancia" version
		echo "Si la versión nueva había cambiado la base de datos, puede que haga falta"
		echo "restaurar la copia de antes (README, apartado 'Restaurar de verdad')." ;;
	soltar)
		rm -f "$fijada_file"
		echo "$nombre vuelve a seguir la rama. Se aplicará en la próxima actualización"
		echo "automática, o ya mismo con: ./nocthold.sh $instancia actualizar" ;;
	auto)
		unidad="nocthold-actualizar-$instancia"
		case "${1:-poner}" in
			poner)
				if [ "$instancia" = prod ]; then
					# Canary hace el server save a las 6:00 (hora de Madrid) y se reinicia.
					cuando="*-*-* 06:01:00 Europe/Madrid"
				else
					cuando="*:0/5"
				fi
				sudo tee "/etc/systemd/system/$unidad.service" >/dev/null <<-EOF
					[Unit]
					Description=Actualiza $nombre con lo último de GitHub
					After=docker.service network-online.target
					Wants=network-online.target

					[Service]
					Type=oneshot
					User=$(id -un)
					ExecStart=$(pwd)/nocthold.sh $instancia actualizar
				EOF
				sudo tee "/etc/systemd/system/$unidad.timer" >/dev/null <<-EOF
					[Unit]
					Description=Actualización automática de $nombre

					[Timer]
					OnCalendar=$cuando

					[Install]
					WantedBy=timers.target
				EOF
				sudo systemctl daemon-reload
				sudo systemctl enable --now "$unidad.timer"
				systemctl list-timers "$unidad.timer" --no-pager ;;
			quitar)
				sudo systemctl disable --now "$unidad.timer" || true
				sudo rm -f "/etc/systemd/system/$unidad.service" "/etc/systemd/system/$unidad.timer"
				sudo systemctl daemon-reload
				echo "Actualización automática de $nombre quitada." ;;
			ver)
				systemctl list-timers "$unidad.timer" --no-pager || true
				journalctl -u "$unidad.service" -n 40 --no-pager ;;
			*)
				echo "Uso: ./nocthold.sh $instancia auto [poner|quitar|ver]"; exit 1 ;;
		esac ;;
	down)
		# Sin -v: nunca borra la base de datos. Para borrarla hay que hacerlo a mano.
		"${compose[@]}" down "$@" ;;
	mapas)
		[ "$instancia" = test ] || { echo "Los mapas privados solo van en pruebas: ./nocthold.sh test mapas <fichero>"; exit 1; }
		listar_mapas() {
			echo "Mapas privados en $mapas_privados:"
			for f in "$mapas_privados"/*.otbm; do
				if [ -e "$f" ]; then echo "  $(basename "$f" .otbm)"; fi
			done
		}
		reiniciar_mapas() {
			echo "Reiniciando pruebas para cargarlos..."
			"${compose[@]}" up -d --force-recreate server
			if esperar_online; then
				"${compose[@]}" logs --no-color --tail 400 server | grep -E "Copied|Portales a los mapas|Portal de entrada|canary map|missing or corrupted|se pisa" || true
				echo "Listo. Mapa principal: $(leer MAP_NAME). Los portales salen en el log de arriba."
			else
				echo "El servidor no ha vuelto a arrancar. Mira: ./nocthold.sh test logs"
				exit 1
			fi
		}
		if [ -z "${1:-}" ]; then
			listar_mapas
			echo "Para añadir o cambiar mapas: ./nocthold.sh test mapas <fichero.tar.gz>"
			echo "Para quitar uno:            ./nocthold.sh test mapas quitar <nombre>"
			exit 0
		fi
		if [ "$1" = quitar ]; then
			quitar="${2:-}"
			[[ "$quitar" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "Uso: ./nocthold.sh test mapas quitar <nombre> (sin .otbm)"; exit 1; }
			[ -f "$mapas_privados/$quitar.otbm" ] || { echo "No hay ningún mapa $quitar"; listar_mapas; exit 1; }
			[ "$quitar" != "$(leer MAP_NAME)" ] ||
				{ echo "$quitar es el mapa principal: cámbialo antes con ./nocthold.sh test mundo canary"; exit 1; }
			rm -f "$mapas_privados/$quitar.otbm" "$mapas_privados/$quitar"-*.xml "$mapas_privados/nocthold_mapa_$quitar.lua"
			if [ -f "$mapas_privados/nocthold_mapas_privados.lua" ]; then
				echo "Ojo: hay un nocthold_mapas_privados.lua de un paquete antiguo con varios mapas juntos."
				echo "Sube un paquete nuevo de cada mapa para que se quite del todo."
			fi
			echo "Quitado $quitar."
			listar_mapas
			reiniciar_mapas
			exit 0
		fi
		paquete="$1"
		[ -f "$paquete" ] || { echo "No encuentro $paquete"; exit 1; }
		# Solo ficheros sueltos .otbm, .xml y .lua, sin carpetas: nada más entra.
		nombres="$(tar -tzf "$paquete")" || { echo "$paquete no es un .tar.gz válido"; exit 1; }
		while IFS= read -r f; do
			[[ "$f" =~ ^[A-Za-z0-9_-]+(\.otbm|\.xml|\.lua)$ ]] ||
				{ echo "Fichero no permitido dentro del paquete: $f"; exit 1; }
		done <<<"$nombres"
		grep -q '\.otbm$' <<<"$nombres" || { echo "El paquete no trae ningún .otbm"; exit 1; }
		if grep -qx 'nocthold_mapas_privados.lua' <<<"$nombres"; then
			# Formato antiguo: un solo .lua con todos los mapas del paquete. Sustituye lo que hubiera.
			echo "Paquete antiguo (todos los mapas en un .lua): sustituye a los mapas que hubiera."
			rm -f "$mapas_privados"/*.otbm "$mapas_privados"/*.xml "$mapas_privados"/*.lua
		else
			# Se suma a lo que hay: los mapas con el mismo nombre se cambian por los nuevos y el resto se queda.
			rm -f "$mapas_privados/nocthold_mapas_privados.lua"
		fi
		tar -xzf "$paquete" -C "$mapas_privados"
		echo "Añadido o cambiado:"
		grep '\.otbm$' <<<"$nombres" | sed 's/\.otbm$//; s/^/  /'
		listar_mapas
		reiniciar_mapas ;;
	mundo)
		[ "$instancia" = test ] || { echo "El mapa principal solo se cambia en pruebas: ./nocthold.sh test mundo <nombre>"; exit 1; }
		if [ -z "${1:-}" ]; then
			echo "Mapa principal de pruebas: $(leer MAP_NAME)"
			echo "Para cambiarlo: ./nocthold.sh test mundo <nombre> (o canary para volver al de Canary)"
			exit 0
		fi
		[[ "$1" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "El nombre es el del .otbm sin la extensión (por ejemplo nocthold_world)"; exit 1; }
		if [ "$1" != canary ] && [ ! -f "$mapas_privados/$1.otbm" ]; then
			echo "No está $1.otbm en $mapas_privados: sube antes el paquete con ./nocthold.sh test mapas <fichero>"
			exit 1
		fi
		if grep -q '^MAP_NAME=' "$env_file"; then
			sed -i "s/^MAP_NAME=.*/MAP_NAME=$1/" "$env_file"
		else
			echo "MAP_NAME=$1" >>"$env_file"
		fi
		echo "Mapa principal de pruebas: $1. Reiniciando..."
		"${compose[@]}" up -d --force-recreate server
		if esperar_online; then
			"${compose[@]}" logs --no-color --tail 400 server | grep -E "Copied|Portales a los mapas|Portal de entrada|canary map|missing or corrupted" || true
			echo "Listo."
		else
			echo "El servidor no ha vuelto a arrancar. Mira: ./nocthold.sh test logs"
			exit 1
		fi ;;
	*)
		"${compose[@]}" "$orden" "$@" ;;
esac
