#!/usr/bin/env python3
"""Deja un OTClient Redemption recién compilado configurado para Nocthold.

Uso (lo ejecuta el workflow .github/workflows/cliente-windows.yml):

    python client/configurar.py <carpeta del cliente> <prod|test>

Cambia:
  * init.lua: Servers_init apunta a nuestro login por HTTP, así el jugador no
    ve los campos de servidor, puerto ni versión: solo correo y contraseña.
    Y el nombre de la aplicación (título de la ventana, log y ajustes).
  * client_entergame/entergame.lua: con un único servidor, OTClient intenta
    cargar los gráficos nada más arrancar; si aún no se han descargado sale
    un error de "Tibia.dat". Solo los precargamos si ya están instalados (si
    no, se descargan al pulsar Login).
  * init.lua (Services.clientAssets): los gráficos se guardan en la carpeta de
    usuario de Windows (%APPDATA%\\nocthold\\...) y no dentro de la del cliente,
    así un .zip nuevo no obliga a descargarlos otra vez. Y no se bajan los
    "extras" del cliente oficial (carpeta bin), que OTClient no necesita.
  * Quita mods/game_bot: OTClient trae un bot (cavebot, targetbot) que no
    queremos repartir a los jugadores. También lo quita de la lista de
    client_mods (si no, el log dice "Unable to find module 'game_bot'") y de
    client_profiles (si no, cambiar de perfil daría un error de Lua).

Si la versión de OTClient cambia y el texto que buscamos ya no está, el script
falla en vez de dejar un cliente a medio configurar.
"""
import re
import shutil
import sys
from pathlib import Path

# Datos públicos de cada instancia (ver infra/canary/instancia.env.example).
SERVIDOR_IP = "158.220.91.85"
PROTOCOLO = 1525  # La imagen de Canary que usamos acepta 15.25 (ver "Allowed client protocols" en su log)

CANALES = {
    "prod": {"nombre": "Nocthold", "corto": "nocthold", "puerto_http": 8088},
    "test": {"nombre": "Nocthold Pruebas", "corto": "nocthold-pruebas", "puerto_http": 8188},
}


def sustituir(texto: str, patron: str, nuevo: str, que: str, fichero: str = "init.lua") -> str:
    resultado, n = re.subn(patron, lambda _m: nuevo, texto, count=1, flags=re.S)
    if n != 1:
        sys.exit(f"ERROR: no encuentro {que} en {fichero}; ¿ha cambiado OTClient?")
    return resultado


PRECARGA_ORIGINAL = (
    "    -- so it can display the boosted creature\n"
    "    g_game.setClientVersion(clientVersion)\n"
    "    g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))\n"
    "end\n"
)
PRECARGA_NOCTHOLD = (
    "    -- so it can display the boosted creature\n"
    "    -- Nocthold: solo si los gráficos ya están descargados (si no, error al arrancar)\n"
    "    local assets = modules.client_assets\n"
    "    if not (assets and assets.isClientVersionInstalled) or assets.isClientVersionInstalled(clientVersion) then\n"
    "        g_game.setClientVersion(clientVersion)\n"
    "        g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))\n"
    "    end\n"
    "end\n"
)


def parchear_entergame(carpeta: Path) -> None:
    fichero = carpeta / "modules" / "client_entergame" / "entergame.lua"
    texto = fichero.read_text(encoding="utf-8")
    if texto.count(PRECARGA_ORIGINAL) != 1:
        sys.exit("ERROR: no encuentro la precarga de gráficos en entergame.lua; ¿ha cambiado OTClient?")
    fichero.write_text(texto.replace(PRECARGA_ORIGINAL, PRECARGA_NOCTHOLD), encoding="utf-8")


def quitar_referencias_bot(carpeta: Path) -> None:
    mods = carpeta / "mods" / "client_mods" / "mods.otmod"
    texto = mods.read_text(encoding="utf-8")
    nuevo = re.sub(r"^[ \t]*- game_bot[ \t]*\r?\n", "", texto, flags=re.M)
    if nuevo == texto:
        sys.exit("ERROR: no encuentro game_bot en mods/client_mods/mods.otmod; ¿ha cambiado OTClient?")
    mods.write_text(nuevo, encoding="utf-8")

    perfiles = carpeta / "mods" / "client_profiles" / "profiles.lua"
    texto = perfiles.read_text(encoding="utf-8")
    original = "  modules.game_bot.refresh()\n"
    if texto.count(original) != 1:
        sys.exit("ERROR: no encuentro modules.game_bot.refresh() en profiles.lua; ¿ha cambiado OTClient?")
    perfiles.write_text(
        texto.replace(original, "  if modules.game_bot then modules.game_bot.refresh() end\n"), encoding="utf-8"
    )


def main() -> None:
    if len(sys.argv) != 3 or sys.argv[2] not in CANALES:
        sys.exit(__doc__)
    carpeta, canal = Path(sys.argv[1]), CANALES[sys.argv[2]]
    init = carpeta / "init.lua"
    texto = init.read_text(encoding="utf-8")

    url = f"http://{SERVIDOR_IP}:{canal['puerto_http']}/login"
    servidores = (
        "    Servers_init = {\n"
        f"        -- {canal['nombre']}: login por HTTP (opentibiabr/login-server)\n"
        f'        ["{url}"] = {{\n'
        f"            port = {canal['puerto_http']},\n"
        f"            protocol = {PROTOCOLO},\n"
        "            httpLogin = true,\n"
        "            useAuthenticator = false\n"
        "        }\n"
        "    }\n"
        "end"
    )
    texto = sustituir(texto, r"    Servers_init = \{\n.*?\n    \}\nend", servidores, "Servers_init")
    texto = sustituir(
        texto, r"installArchiveExtras = true,", "installArchiveExtras = false,", "installArchiveExtras"
    )
    texto = sustituir(
        texto,
        r"installPackagedFiles = true\n",
        "installPackagedFiles = false,\n        installInWorkDir = false\n",
        "installPackagedFiles",
    )
    texto = sustituir(texto, r'g_app\.setName\("[^"]*"\)', f'g_app.setName("{canal["nombre"]}")', "setName")
    texto = sustituir(
        texto, r'g_app\.setCompactName\("[^"]*"\)', f'g_app.setCompactName("{canal["corto"]}")', "setCompactName"
    )
    texto = sustituir(
        texto, r'g_app\.setOrganizationName\("[^"]*"\)', 'g_app.setOrganizationName("nocthold")', "setOrganizationName"
    )

    init.write_text(texto, encoding="utf-8")
    parchear_entergame(carpeta)
    bot = carpeta / "mods" / "game_bot"
    if bot.exists():
        shutil.rmtree(bot)
        print("Quitado el bot integrado (mods/game_bot)")
    quitar_referencias_bot(carpeta)
    print(f"init.lua configurado para {canal['nombre']} ({url}, protocolo {PROTOCOLO})")


if __name__ == "__main__":
    main()
