#!/usr/bin/env python3
"""Genera la lista de ficheros que lee el actualizador del cliente.

Uso (lo ejecuta el workflow .github/workflows/cliente-windows.yml):

    python client/manifiesto.py <carpeta del cliente> <url de los ficheros> <versión> <salida.json>

Recorre lo que el actualizador puede cambiar (init.lua, otclientrc.lua, data/,
modules/ y mods/; nunca el .exe) y apunta la huella crc32 de cada fichero, en
el mismo formato que calcula OTClient (hexadecimal en minúsculas, sin ceros a
la izquierda). Ver client/actualizador/updater.lua.
"""
import json
import sys
import zlib
from pathlib import Path

FICHEROS = ("init.lua", "otclientrc.lua")
CARPETAS = ("data", "modules", "mods")


def huella(fichero: Path) -> str:
    return format(zlib.crc32(fichero.read_bytes()) & 0xFFFFFFFF, "x")


def listar(carpeta: Path) -> dict[str, str]:
    ficheros = {}
    for nombre in FICHEROS:
        if (carpeta / nombre).is_file():
            ficheros["/" + nombre] = huella(carpeta / nombre)
    for nombre in CARPETAS:
        for fichero in sorted((carpeta / nombre).rglob("*")):
            if fichero.is_file():
                ficheros["/" + fichero.relative_to(carpeta).as_posix()] = huella(fichero)
    if "/init.lua" not in ficheros or not any(f.startswith("/modules/updater/") for f in ficheros):
        sys.exit(f"ERROR: {carpeta} no parece un cliente configurado (falta init.lua o modules/updater)")
    return ficheros


def main() -> None:
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    carpeta, url, version, salida = Path(sys.argv[1]), sys.argv[2], sys.argv[3], Path(sys.argv[4])
    if not url.endswith("/"):
        url += "/"
    ficheros = listar(carpeta)
    salida.write_text(
        json.dumps({"version": version, "url": url, "files": ficheros}, indent=1, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"{salida}: {len(ficheros)} ficheros, versión {version}")


if __name__ == "__main__":
    main()
