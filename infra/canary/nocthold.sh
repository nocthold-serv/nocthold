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
		bd=nocthold_prod; gm="GM Nocthold" ;;
	test)
		nombre="Nocthold Pruebas"; login=7271; juego=7272; estado=7273; http=8188; web=8180
		bd=nocthold_test; gm="GM Pruebas" ;;
	*)
		sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
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
		printf '%s\n' "$linea"
	done <instancia.env.example >"$env_file"
	echo "Hecho. Las contraseñas están en $(pwd)/$env_file (guárdalas en Bitwarden)."
fi

leer() { grep -m1 "^$1=" "$env_file" | cut -d= -f2-; }
compose=(docker compose -p "nocthold-$instancia" --env-file "$env_file")
shift 2

case "$orden" in
	up)
		"${compose[@]}" up -d --build --remove-orphans "$@"
		"${compose[@]}" ps ;;
	stop)
		"${compose[@]}" stop "$@" ;;
	logs)
		"${compose[@]}" logs -f --tail 200 "${@:-server}" ;;
	ram)
		docker stats --no-stream \
			--format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}' \
			$(docker ps -q --filter "label=com.docker.compose.project=nocthold-$instancia") ;;
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
	down)
		# Sin -v: nunca borra la base de datos. Para borrarla hay que hacerlo a mano.
		"${compose[@]}" down "$@" ;;
	*)
		"${compose[@]}" "$orden" "$@" ;;
esac
