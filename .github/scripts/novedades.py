#!/usr/bin/env python3
"""Novedades para los jugadores en cada push a la rama prod.

Busca los PR que entran en prod con este push (sin contar los PR que solo
pasan develop -> main -> prod), saca de cada uno el apartado
"## Para los jugadores" de su descripción y, si hay algo, crea una Release
de GitHub "Novedades del <día>" con el texto listo para pegar en Discord.

Uso (lo lanza .github/workflows/novedades.yml):
    novedades.py <repo> <sha_antes> <sha_despues>
Sin GH_TOKEN, con --prueba <fichero.json> lee los PR de un fichero (para tests).
"""
import datetime as dt
import json
import re
import subprocess
import sys
from zoneinfo import ZoneInfo

SECCION = re.compile(r"^#{2,3}\s*Para los jugadores\s*$(.*?)(?=^#{1,3}\s|\Z)", re.M | re.S | re.I)
VACIO = {"", "-", "nada", "ninguno", "ninguna", "no", "n/a", "nada para los jugadores"}
MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
         "septiembre", "octubre", "noviembre", "diciembre"]
RAMAS_DE_PASO = {"develop", "main", "prod"}


def gh(*args):
    return subprocess.run(["gh", "api", *args], check=True, capture_output=True, text=True).stdout


def nota_de(cuerpo):
    m = SECCION.search(cuerpo or "")
    if not m:
        return ""
    texto = re.sub(r"<!--.*?-->", "", m.group(1), flags=re.S).strip()
    if texto.lower().strip(" .") in VACIO:
        return ""
    lineas = [l.rstrip() for l in texto.splitlines() if l.strip()]
    # Cada frase suelta pasa a ser un punto de la lista.
    return "\n".join(l if l.lstrip().startswith(("-", "*", "•")) or l.startswith("  ") else f"- {l}" for l in lineas)


def prs_del_push(repo, antes, despues):
    shas = json.loads(gh(f"repos/{repo}/compare/{antes}...{despues}", "--jq", "[.commits[].sha]"))
    vistos = {}
    for sha in shas:
        for pr in json.loads(gh(f"repos/{repo}/commits/{sha}/pulls")):
            if pr.get("merged_at") and pr["head"]["ref"] not in RAMAS_DE_PASO:
                vistos[pr["number"]] = pr
    return sorted(vistos.values(), key=lambda p: p["merged_at"])


def dia_que_llega(ahora):
    # Producción aplica los cambios a las 6:01 (hora de Madrid).
    madrid = ahora.astimezone(ZoneInfo("Europe/Madrid"))
    dia = madrid.date() if madrid.hour < 6 else madrid.date() + dt.timedelta(days=1)
    return dia, f"{dia.day} de {MESES[dia.month - 1]}"


def texto(prs, ahora):
    notas = [n for n in (nota_de(p.get("body")) for p in prs) if n]
    if not notas:
        return None, None, None
    dia, bonito = dia_que_llega(ahora)
    cuerpo = "\n".join([
        f"**Novedades de Nocthold del {bonito}**",
        "",
        "Llegan con el reinicio de las 6:00.",
        "",
        *notas,
    ])
    return dia, bonito, cuerpo


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--prueba":
        prs = json.load(open(sys.argv[2]))
        print(texto(prs, dt.datetime.now(dt.timezone.utc))[2])
        return
    repo, antes, despues = sys.argv[1:4]
    if set(antes) == {"0"}:
        print("Rama nueva: no hay con qué comparar.")
        return
    prs = prs_del_push(repo, antes, despues)
    dia, bonito, cuerpo = texto(prs, dt.datetime.now(dt.timezone.utc))
    if not cuerpo:
        print(f"Ningún PR de este push trae novedades para los jugadores ({len(prs)} PR revisados).")
        return
    etiquetas = set(gh(f"repos/{repo}/tags", "--paginate", "--jq", ".[].name").split())
    etiqueta, n = f"novedades-{dia.isoformat()}", 2
    while etiqueta in etiquetas:
        etiqueta, n = f"novedades-{dia.isoformat()}-{n}", n + 1
    subprocess.run(["gh", "release", "create", etiqueta, "--repo", repo, "--target", despues,
                    "--title", f"Novedades del {bonito}", "--notes", cuerpo, "--latest=false"], check=True)
    print(cuerpo)
    print("\nPR incluidos: " + ", ".join(f"#{p['number']}" for p in prs))


if __name__ == "__main__":
    main()
