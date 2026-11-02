#!/usr/bin/env bash
# Copia diaria de las bases de datos, subida a Google Drive (issue #24).
# La lanza cron cada noche (ver README, apartado "Copias de seguridad").
#
#  - Hace una copia de cada instancia que esté en marcha (prod y, si existe, test).
#  - La sube a la carpeta "nocthold-copias" del Drive del equipo con rclone.
#  - Guarda 7 días en el VPS y 30 días en Drive.
#  - Los domingos comprueba que la última copia de prod se puede restaurar.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
REMOTO="${REMOTO:-gdrive:nocthold-copias}"

echo "===== $(date '+%Y-%m-%d %H:%M') ====="
for instancia in prod test; do
	[ -f "$instancia.env" ] || continue
	if [ -z "$(docker ps -q --filter "label=com.docker.compose.project=nocthold-$instancia" --filter "label=com.docker.compose.service=db")" ]; then
		echo "$instancia: no está en marcha, se salta."
		continue
	fi
	./nocthold.sh "$instancia" backup
	rclone copy "$HOME/copias/$instancia" "$REMOTO/$instancia" --include "*.sql.gz"
	find "$HOME/copias/$instancia" -name '*.sql.gz' -mtime +7 -delete
	rclone delete "$REMOTO/$instancia" --min-age 30d --include "*.sql.gz"
	echo "$instancia: subida a $REMOTO/$instancia"
done

if [ "$(date +%u)" = 7 ] && [ -f prod.env ]; then
	./nocthold.sh prod probar-copia
fi
echo "Todo correcto."
