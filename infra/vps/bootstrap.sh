#!/usr/bin/env bash
# Nocthold - preparación y seguridad del VPS (fase 1 del roadmap).
# Ubuntu Server 24.04 LTS. Se ejecuta como root o con sudo:
#   sudo bash bootstrap.sh
# Se puede ejecutar varias veces sin romper nada (por ejemplo, para añadir
# la clave de una persona nueva).
#
# Qué hace:
#   1. Crea el usuario de administración (por defecto "nocthold") con sudo.
#   2. Instala las claves SSH de authorized_keys (una por persona).
#   3. SSH solo con clave, sin contraseña y sin login de root.
#   4. Cortafuegos ufw: SSH, 80/443, puertos de prod y de pruebas.
#   5. fail2ban para SSH.
#   6. Actualizaciones de seguridad automáticas.
#   7. Zona horaria Europe/Madrid y swap.
#   8. Docker Engine + Docker Compose (plugin oficial).
set -euo pipefail

# ---------- Ajustes (se pueden cambiar con variables de entorno) ----------
ADMIN_USER="${ADMIN_USER:-nocthold}"
SWAP_SIZE="${SWAP_SIZE:-4G}"
TIMEZONE="${TIMEZONE:-Europe/Madrid}"
KEYS_URL="${KEYS_URL:-https://raw.githubusercontent.com/nocthold-serv/nocthold/develop/infra/vps/authorized_keys}"
# Puertos del juego. prod: login 7171, juego 7172, estado 7173.
# pruebas: los mismos +100 (7271, 7272, 7273).
GAME_PORTS="${GAME_PORTS:-7171 7172 7173 7271 7272 7273}"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[aviso] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Ejecútalo con sudo:  sudo bash $0"
. /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || warn "Pensado para Ubuntu 24.04; detectado ${PRETTY_NAME:-desconocido}."

export DEBIAN_FRONTEND=noninteractive
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 0. Paquetes base ----------
log "Actualizando el sistema e instalando paquetes base"
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg ufw fail2ban unattended-upgrades \
  apt-listchanges htop git

# ---------- 1. Usuario de administración ----------
log "Usuario de administración: $ADMIN_USER"
if ! id "$ADMIN_USER" &>/dev/null; then
  adduser --disabled-password --gecos "Nocthold admin" "$ADMIN_USER"
fi
usermod -aG sudo "$ADMIN_USER"
# sudo sin contraseña: el usuario no tiene contraseña, solo clave SSH.
echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$ADMIN_USER"
chmod 440 "/etc/sudoers.d/90-$ADMIN_USER"
visudo -cf "/etc/sudoers.d/90-$ADMIN_USER" >/dev/null

# ---------- 2. Claves SSH ----------
log "Instalando claves SSH"
KEYS_FILE="$SCRIPT_DIR/authorized_keys"
if [[ ! -f "$KEYS_FILE" ]]; then
  KEYS_FILE="$(mktemp)"
  curl -fsSL "$KEYS_URL" -o "$KEYS_FILE" || die "No pude descargar las claves de $KEYS_URL"
fi
HOME_DIR="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$HOME_DIR/.ssh"
AUTH="$HOME_DIR/.ssh/authorized_keys"
touch "$AUTH"
added=0
while IFS= read -r line; do
  line="${line%$'\r'}"
  [[ -z "${line// }" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-|sk-) ]] || { warn "Línea ignorada (no parece una clave): ${line:0:40}"; continue; }
  keybody="$(awk '{print $2}' <<<"$line")"
  if ! grep -qF "$keybody" "$AUTH"; then
    echo "$line" >> "$AUTH"; added=$((added+1))
  fi
done < "$KEYS_FILE"
chown "$ADMIN_USER:$ADMIN_USER" "$AUTH"; chmod 600 "$AUTH"
total="$(grep -cE '^(ssh-|ecdsa-|sk-)' "$AUTH" || true)"
echo "Claves nuevas: $added. Total instaladas: $total."
[[ "$total" -ge 1 ]] || die "No hay ninguna clave instalada para $ADMIN_USER. No toco SSH para no dejarte fuera."

# ---------- 3. SSH endurecido ----------
log "Configurando SSH: solo clave, sin root"
# El nombre empieza por 00- para ganar a 50-cloud-init.conf (en sshd gana el primer valor).
cat > /etc/ssh/sshd_config.d/00-nocthold.conf <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowUsers $ADMIN_USER
EOF
sshd -t || die "La configuración de SSH tiene un error; no la aplico."
systemctl reload ssh || systemctl restart ssh

# ---------- 4. Cortafuegos ----------
log "Cortafuegos ufw"
ufw default deny incoming
ufw default allow outgoing
ufw limit 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'web'
ufw allow 443/tcp comment 'web https'
for p in $GAME_PORTS; do ufw allow "$p/tcp" comment 'juego'; done
ufw --force enable
ufw status verbose

# ---------- 5. fail2ban ----------
log "fail2ban"
cat > /etc/fail2ban/jail.d/nocthold.local <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled = true
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

# ---------- 6. Actualizaciones de seguridad automáticas ----------
log "Actualizaciones automáticas de seguridad"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
cat > /etc/apt/apt.conf.d/52nocthold-unattended <<'EOF'
// Reinicia solo si hace falta, de madrugada (hora de Madrid).
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "05:30";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
systemctl enable --now unattended-upgrades

# ---------- 7. Zona horaria y swap ----------
log "Zona horaria $TIMEZONE y swap $SWAP_SIZE"
timedatectl set-timezone "$TIMEZONE"
timedatectl set-ntp true || true
if ! swapon --show | grep -q '/swapfile'; then
  if [[ ! -f /swapfile ]]; then
    fallocate -l "$SWAP_SIZE" /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$(( ${SWAP_SIZE%G} * 1024 ))
    chmod 600 /swapfile
    mkswap /swapfile
  fi
  swapon /swapfile
fi
grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
echo 'vm.swappiness=10' > /etc/sysctl.d/99-nocthold.conf
sysctl -p /etc/sysctl.d/99-nocthold.conf >/dev/null

# ---------- 8. Docker + Compose ----------
log "Docker Engine y Docker Compose"
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
# Logs de contenedores limitados para no llenar el disco.
if [[ ! -f /etc/docker/daemon.json ]]; then
  cat > /etc/docker/daemon.json <<'EOF'
{ "log-driver": "json-file", "log-opts": { "max-size": "20m", "max-file": "5" } }
EOF
  systemctl restart docker
fi
systemctl enable --now docker
usermod -aG docker "$ADMIN_USER"

# ---------- Resumen ----------
log "Listo"
echo "Usuario:      $ADMIN_USER (sudo + docker)"
echo "Claves SSH:   $total"
echo "Zona horaria: $(timedatectl show -p Timezone --value)"
echo "Swap:         $(swapon --show=SIZE --noheadings | head -1)"
echo "Docker:       $(docker --version)"
echo "Compose:      $(docker compose version)"
echo
warn "NO cierres esta ventana todavía. Abre otra y prueba:  ssh $ADMIN_USER@<IP-del-VPS>"
warn "Ojo: Docker se salta ufw en los puertos que publica. Nunca publiques el puerto de MariaDB (3306)."
