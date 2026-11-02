#!/usr/bin/env python3
"""Deja un OTClient Redemption recién compilado configurado para Nocthold.

Uso (lo ejecuta el workflow .github/workflows/cliente-windows.yml):

    python client/configurar.py <carpeta del cliente> <prod|test>

Cambia solo init.lua:
  * Servers_init apunta a nuestro login por HTTP, así el jugador no ve los
    campos de servidor, puerto ni versión: solo correo y contraseña.
  * Nombre de la aplicación (título de la ventana, log y ajustes).

Si la versión de OTClient cambia y el texto que buscamos ya no está, el script
falla en vez de dejar un cliente a medio configurar.
"""
import re
import sys
from pathlib import Path

# Datos públicos de cada instancia (ver infra/canary/instancia.env.example).
SERVIDOR_IP = "158.220.91.85"
PROTOCOLO = 1511  # Canary 3.6.x = cliente 15.11

CANALES = {
    "prod": {"nombre": "Nocthold", "corto": "nocthold", "puerto_http": 8088},
    "test": {"nombre": "Nocthold Pruebas", "corto": "nocthold-pruebas", "puerto_http": 8188},
}


def sustituir(texto: str, patron: str, nuevo: str, que: str) -> str:
    resultado, n = re.subn(patron, lambda _m: nuevo, texto, count=1, flags=re.S)
    if n != 1:
        sys.exit(f"ERROR: no encuentro {que} en init.lua; ¿ha cambiado OTClient?")
    return resultado


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
    texto = sustituir(texto, r'g_app\.setName\("[^"]*"\)', f'g_app.setName("{canal["nombre"]}")', "setName")
    texto = sustituir(
        texto, r'g_app\.setCompactName\("[^"]*"\)', f'g_app.setCompactName("{canal["corto"]}")', "setCompactName"
    )
    texto = sustituir(
        texto, r'g_app\.setOrganizationName\("[^"]*"\)', 'g_app.setOrganizationName("nocthold")', "setOrganizationName"
    )

    init.write_text(texto, encoding="utf-8")
    print(f"init.lua configurado para {canal['nombre']} ({url}, protocolo {PROTOCOLO})")


if __name__ == "__main__":
    main()
