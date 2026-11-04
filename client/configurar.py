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
  * Hechizos (ver client/hechizos/LEEME.md): quita los hechizos de Tibia de
    modules/gamelib/spells.lua y pone los nuestros, leídos de los ficheros del
    servidor (data-nocthold/scripts/nocthold/spells), con sus descripciones
    (client/hechizos/descripciones.json) y nuestros iconos (iconos-32.png e
    iconos-20.png) en lugar de los de Tibia. El texto de la barra de acciones
    al pasar el ratón sale en español y con la descripción.
  * Actualizador (Services.updater): al arrancar, el cliente mira la lista de
    ficheros publicada en la rama cliente-actualizaciones y se baja lo que haya
    cambiado. Usa nuestro modules/updater/updater.lua (client/actualizador/),
    no el de OTClient. Ver "Actualizaciones automáticas" en client/README.md.

Si la versión de OTClient cambia y el texto que buscamos ya no está, el script
falla en vez de dejar un cliente a medio configurar.
"""
import json
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HECHIZOS_SERVIDOR = REPO / "data-nocthold" / "scripts" / "nocthold" / "spells"
HECHIZOS_CLIENTE = REPO / "client" / "hechizos"

# Datos públicos de cada instancia (ver infra/canary/instancia.env.example).
SERVIDOR_IP = "158.220.91.85"
PROTOCOLO = 1525  # La imagen de Canary que usamos acepta 15.25 (ver "Allowed client protocols" en su log)

# Rama donde el workflow publica los ficheros del cliente para el actualizador.
ACTUALIZACIONES = "https://raw.githubusercontent.com/nocthold-serv/nocthold/cliente-actualizaciones"

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


def poner_actualizador(carpeta: Path) -> None:
    destino = carpeta / "modules" / "updater" / "updater.lua"
    if not destino.exists():
        sys.exit("ERROR: no encuentro modules/updater/updater.lua; ¿ha cambiado OTClient?")
    shutil.copyfile(REPO / "client" / "actualizador" / "updater.lua", destino)


# ------------------------------------------------------------------ hechizos
# Números de vocación que usa OTClient (VocationNames en modules/gamelib/spells.lua)
VOCACIONES_CLIENTE = {
    "sorcerer": 1, "druid": 2, "paladin": 3, "knight": 4, "master sorcerer": 5,
    "elder druid": 6, "royal paladin": 7, "elite knight": 8, "monk": 9, "exalted monk": 10,
}
GRUPOS = {"attack": 1, "healing": 2, "support": 3}
ID_BASE = 1001  # el icono del hechizo con id N está en la posición N - ID_BASE de la tira


def leer_hechizos_servidor() -> list[dict]:
    """Lee nombre, palabras, id, maná... de cada hechizo del servidor (spell:xxx(...))."""
    hechizos = []
    for fichero in sorted(HECHIZOS_SERVIDOR.glob("*.lua")):
        datos = {}
        for clave, args in re.findall(r"^spell:(\w+)\((.*)\)\s*$", fichero.read_text(encoding="utf-8"), flags=re.M):
            datos[clave] = args.strip()
        faltan = [c for c in ("name", "words", "id", "group", "cooldown", "level", "mana", "vocation") if c not in datos]
        if faltan:
            sys.exit(f"ERROR: al hechizo {fichero.name} le falta spell:{', spell:'.join(faltan)}")
        texto = lambda c: json.loads(datos[c])  # "..." -> ...
        vocaciones = sorted(
            VOCACIONES_CLIENTE[v.split(";")[0].strip().lower()] for v in re.findall(r'"([^"]+)"', datos["vocation"])
        )
        grupo = datos["group"].split(",")[0].strip().strip('"')
        if grupo not in GRUPOS:
            sys.exit(f"ERROR: grupo '{grupo}' desconocido en {fichero.name}")
        hechizos.append(
            {
                "fichero": fichero.name,
                "nombre": texto("name"),
                "palabras": texto("words").lower(),
                "id": int(datos["id"]),
                "grupo": GRUPOS[grupo],
                "enfriamiento": int(datos["cooldown"]),
                "enfriamiento_grupo": int(datos.get("groupCooldown", "1000")),
                "nivel": int(datos["level"]),
                "mana": int(datos["mana"]),
                "objetivo": datos.get("needTarget", "false") == "true",
                "alcance": int(datos.get("range", "-1")),
                "vocaciones": vocaciones,
            }
        )
    return hechizos


def lua_texto(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def tabla_hechizos(hechizos: list[dict], descripciones: dict) -> str:
    lineas = [
        "-- Nocthold: solo nuestros hechizos (generado por client/configurar.py a partir de",
        "-- data-nocthold/scripts/nocthold/spells). Los de Tibia no se usan en Nocthold.",
        "SpellInfo = {",
        "    Default = {",
    ]
    for h in sorted(hechizos, key=lambda h: h["id"]):
        campos = [
            f"id = {h['id']}",
            f"name = {lua_texto(h['nombre'])}",
            f"words = {lua_texto(h['palabras'])}",
            "type = 'Instant'",
            f"level = {h['nivel']}",
            f"mana = {h['mana']}",
            "soul = 0",
            "maglevel = 0",
            "icon = ''",
            f"clientId = {h['id'] - ID_BASE}",
            f"group = {{[{h['grupo']}] = {h['enfriamiento_grupo']}}}",
            f"needTarget = {'true' if h['objetivo'] else 'false'}",
            "parameter = false",
            f"range = {h['alcance']}",
            f"exhaustion = {h['enfriamiento']}",
            "premium = false",
            f"vocations = {{{', '.join(map(str, h['vocaciones']))}}}",
            "special = false",
            "source = 0",
            f"description = {lua_texto(descripciones[h['nombre']])}",
        ]
        lineas.append(f"        [{lua_texto(h['nombre'])}] = {{{', '.join(campos)}}},")
    lineas += ["    }", "}", ""]
    return "\n".join(lineas)


TOOLTIP_ORIGINAL = (
    '        return " Cooldown:  " .. cooldown .. "s\\n" .. "         Mana:  " .. mana\n',
    '            actionDesc = "Cast " .. Spells.getSpellNameByWords(spellData.words) .. "\\n"\n'
    '            actionDesc = actionDesc .. "   Formula:  " .. cache.param .. "\\n"\n',
)
TOOLTIP_NOCTHOLD = (
    '        return "Enfriamiento:  " .. cooldown .. " s\\n" .. "           Maná:  " .. mana\n',
    '            actionDesc = Spells.getSpellNameByWords(spellData.words) .. "\\n"\n'
    "            if spellData.description then\n"
    "                -- Nocthold: la descripción, partida en líneas de unas 40 letras sin cortar palabras\n"
    '                local linea, partes = "", {}\n'
    '                for palabra in spellData.description:gmatch("%S+") do\n'
    '                    if linea ~= "" and #linea + #palabra + 1 > 40 then\n'
    "                        partes[#partes + 1] = linea\n"
    "                        linea = palabra\n"
    "                    else\n"
    '                        linea = linea == "" and palabra or (linea .. " " .. palabra)\n'
    "                    end\n"
    "                end\n"
    "                partes[#partes + 1] = linea\n"
    '                actionDesc = actionDesc .. table.concat(partes, "\\n") .. "\\n"\n'
    "            end\n",
)


def poner_hechizos(carpeta: Path) -> None:
    hechizos = leer_hechizos_servidor()
    descripciones = json.loads((HECHIZOS_CLIENTE / "descripciones.json").read_text(encoding="utf-8"))
    descripciones.pop("_leeme", None)

    # Comprobaciones: si algo no cuadra, mejor fallar aquí que repartir un cliente roto.
    errores = []
    ids = [h["id"] for h in hechizos]
    palabras = [h["palabras"] for h in hechizos]
    if len(set(ids)) != len(ids):
        errores.append("hay ids de hechizo repetidos")
    if len(set(palabras)) != len(palabras):
        errores.append("hay palabras de hechizo repetidas")
    for tam in (32, 20):
        # ancho del PNG: bytes 16-19 de la cabecera (así no hace falta instalar Pillow en Windows)
        ancho = int.from_bytes((HECHIZOS_CLIENTE / f"iconos-{tam}.png").read_bytes()[16:20], "big")
        if ancho < tam * (max(ids) - ID_BASE + 1):
            errores.append(f"iconos-{tam}.png no tiene icono para el id {max(ids)} (vuelve a ejecutar dibujar_iconos.py)")
    for h in hechizos:
        if h["id"] < ID_BASE:
            errores.append(f"{h['fichero']}: el id {h['id']} es menor que {ID_BASE}")
        if h["nombre"] not in descripciones:
            errores.append(f"{h['fichero']}: falta la descripción de '{h['nombre']}' en descripciones.json")
    sobran = set(descripciones) - {h["nombre"] for h in hechizos}
    if sobran:
        errores.append(f"descripciones.json tiene hechizos que no existen: {', '.join(sorted(sobran))}")
    for nombre, texto in descripciones.items():
        try:
            texto.encode("latin-1")
        except UnicodeEncodeError:
            errores.append(f"la descripción de '{nombre}' tiene letras que el cliente no sabe mostrar")
    if errores:
        sys.exit("ERROR en los hechizos:\n  - " + "\n  - ".join(errores))

    # El cliente muestra el texto en Latin-1 (como data/locales/es.lua), así que lo escribimos así.
    # (read_bytes y no read_text para no tocar la codificación; en Windows git puede dar \r\n)
    fichero = carpeta / "modules" / "gamelib" / "spells.lua"
    texto = fichero.read_bytes().replace(b"\r\n", b"\n")
    texto, n = re.subn(
        rb"^SpellInfo = \{\n.*?\n\}\n(?=\s*VocationNames = \{)",
        lambda _m: tabla_hechizos(hechizos, descripciones).encode("latin-1"),
        texto,
        count=1,
        flags=re.S | re.M,
    )
    if n != 1:
        sys.exit("ERROR: no encuentro la tabla SpellInfo en modules/gamelib/spells.lua; ¿ha cambiado OTClient?")
    fichero.write_bytes(texto)

    boton = carpeta / "modules" / "game_actionbar" / "logics" / "ActionButtonLogic.lua"
    texto = boton.read_bytes().replace(b"\r\n", b"\n")
    for original, nuevo in zip(TOOLTIP_ORIGINAL, TOOLTIP_NOCTHOLD):
        original_b, nuevo_b = original.encode("latin-1"), nuevo.encode("latin-1")
        if texto.count(original_b) != 1:
            sys.exit("ERROR: no encuentro el texto del hechizo en ActionButtonLogic.lua; ¿ha cambiado OTClient?")
        texto = texto.replace(original_b, nuevo_b)
    boton.write_bytes(texto)

    # Nuestros iconos en lugar de los de Tibia (mismo nombre de fichero: todo el cliente los usa).
    iconos = carpeta / "data" / "images" / "game" / "spells"
    shutil.copyfile(HECHIZOS_CLIENTE / "iconos-32.png", iconos / "spell-icons-32x32.png")
    shutil.copyfile(HECHIZOS_CLIENTE / "iconos-20.png", iconos / "spell-icons-20x20.png")
    print(f"Hechizos: {len(hechizos)} de Nocthold (ids {min(ids)}-{max(ids)}), sin los de Tibia")


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

    lista = f"{ACTUALIZACIONES}/{canal['corto']}/lista.json"
    texto = sustituir(
        texto,
        r'    --updater = "[^"]*",[^\n]*\n',
        f'    updater = "{lista}", -- Nocthold: ./updater (client/actualizador)\n',
        "Services.updater",
    )

    init.write_text(texto, encoding="utf-8")
    poner_actualizador(carpeta)
    parchear_entergame(carpeta)
    bot = carpeta / "mods" / "game_bot"
    if bot.exists():
        shutil.rmtree(bot)
        print("Quitado el bot integrado (mods/game_bot)")
    quitar_referencias_bot(carpeta)
    poner_hechizos(carpeta)
    print(f"init.lua configurado para {canal['nombre']} ({url}, protocolo {PROTOCOLO})")


if __name__ == "__main__":
    main()
