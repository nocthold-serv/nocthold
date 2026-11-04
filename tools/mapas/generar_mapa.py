#!/usr/bin/env python3
"""Genera mapas .otbm de Nocthold a partir de un plano dibujado con letras.

Uso (desde la carpeta del repositorio):
    python3 tools/mapas/generar_mapa.py              # genera todos los planos de tools/mapas/planos/
    python3 tools/mapas/generar_mapa.py --comprobar  # solo mira que lo generado está al día (GitHub)
    python3 tools/mapas/generar_mapa.py --planos MIS_PLANOS --salida MI_CARPETA  # diseños privados

Por cada plano escribe en data-nocthold/world/custom/ el mapa <nombre>.otbm y sus
cuatro ficheros acompañantes (monstruos, NPC, casas y zonas, vacíos). Canary carga
solo todos los .otbm de esa carpeta al arrancar con DATA_PACK=data-nocthold.
Además escribe data-nocthold/scripts/lib/nocthold_mapas.lua con la lista de mapas,
sus puntos con nombre y lo que debe haber en cada casilla (lo usa la prueba
automática y el comando /nocthold mapa).

Leyenda del plano (una letra = una casilla; ver README.md):
    .   suelo                 #  pared               +  puerta (dentro de una pared)
    P   suelo en zona protegida (no se puede atacar)
    E   entrada (obligatoria, una sola)              J  jefe
    1-9 y otras mayúsculas: suelo con un punto con nombre para los scripts ("punto K: jefe1" le da nombre;
                            "destino K: templo", "destino K: jefe1" o "destino K: X Y Z" lo convierte en portal)
    a-z (minúsculas): un monstruo del grupo (pull) de esa letra; "grupo a: Nombre" dice cuál
                      y "radio a: 4" el radio de aggro (si no, lo decide el script de aggro)
    espacio o ~: nada
Con "paredes_auto: si" (por defecto), toda casilla vacía que toca suelo (también en
diagonal) se convierte en pared. Las paredes se orientan solas, igual que el pincel
del RME (horizontal, vertical, esquina o poste según sus vecinas).

Debajo del plano puede haber dos capas, casilla a casilla con él (ver README.md):
    capa zonas:    letras de "zona X: suelo <material>, pared <material>"
    capa objetos:  letras de "objeto X: <IDs>" o "objeto X: pared <ID horizontal> <ID vertical>"
Los suelos con borde (agua, brea, barro...) ponen su borde en las casillas de alrededor.
Con "exterior: <suelo>" se rellena lo de alrededor del dibujo (sin fondo vacío). Otros pisos van en
"plano 6:", "plano 8:"..., y "subida R: norte" pone una rampa en R que sube al piso de arriba.
"""

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import apariencias  # noqa: E402
import otbm  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", ".."))
PLANOS = os.path.join(AQUI, "planos")
SALIDA_MAPAS = os.path.join(RAIZ, "data-nocthold", "world", "custom")
SALIDA_LUA = os.path.join(RAIZ, "data-nocthold", "scripts", "lib", "nocthold_mapas.lua")

# Portales: campo mágico (magic forcefield). Con "destino X: templo" lleva el action id que usa
# data-nocthold/scripts/nocthold/mapas_portales.lua para mandar al templo del jugador.
PORTAL = 1949
AID_TEMPLO = 45200

# Zona reservada para la sala de La Forja Caída que se genera al arrancar (encounter_runtime.lua).
ZONA_BUILDMAP = (64000, 64000, 64080, 64030, [7])

# Va en la descripción de cada .otbm generado (se ve en el RME, en las propiedades del mapa).
MARCA = "(generado por tools/mapas/generar_mapa.py)"

VACIO = " ~"
SUELO = ".PE+#"  # caracteres con significado fijo; el resto de letras/números son puntos
CAPAS = ("zonas", "objetos")  # dibujos extra debajo del plano, con las mismas filas y columnas

# Subidas entre pisos ("subida R: norte"): hacia dónde se camina para subir, en (columnas, filas).
DIRECCIONES = {"norte": (0, -1), "sur": (0, 1), "este": (1, 0), "oeste": (-1, 0)}
# Escalera de bajada (es un suelo): va en el piso de arriba, justo encima de la rampa. Como el pincel del RME.
BAJADA = 469
# Casillas de exterior alrededor del dibujo por defecto ("margen: N"): un poco más de lo que se ve en pantalla.
MARGEN = 10

# Qué objetos bloquean el paso: lo dice el catálogo del cliente (appearances.dat).
APARIENCIAS = os.path.join(RAIZ, "data", "items", "appearances.dat")
_objetos = None


def objetos_del_juego():
    global _objetos
    if _objetos is None:
        _objetos = apariencias.leer_objetos(APARIENCIAS)
    return _objetos


class ErrorPlano(Exception):
    pass


def cargar_materiales():
    with open(os.path.join(AQUI, "materiales.json"), encoding="utf-8") as f:
        return json.load(f)


def leer_plano(texto, origen_fichero="plano"):
    """Devuelve (opciones, filas) de un plano. Lanza ErrorPlano con la línea del fallo.

    filas son las del plano principal ("plano:", en el piso de 'origen'). Los otros pisos
    ("plano 6:", "plano 8:"...) van en opciones["pisos"], con las filas tal como están escritas."""
    opciones = {"paredes_auto": "si", "grupos": {}, "radios": {}, "puntos": {}, "destinos": {},
                "zonas": {}, "objetos": {}, "capas": {}, "subidas": {}, "exteriores": {}, "pisos": {}, "cofres": {}}
    filas = None
    capas = None  # las capas del plano que se está leyendo
    actual = None  # la lista donde van las filas que se leen ahora (un plano o una capa)
    for numero, linea in enumerate(texto.splitlines(), start=1):
        nuevo_plano = re.fullmatch(r"\s*plano(?:\s+(\d+))?\s*:\s*", linea)
        if nuevo_plano:
            if nuevo_plano.group(1) is None:
                if filas is not None:
                    raise ErrorPlano(f"{origen_fichero}:{numero}: hay dos 'plano:' (los otros pisos son 'plano 6:', 'plano 8:'...)")
                filas = actual = []
                capas = opciones["capas"]
            else:
                z = int(nuevo_plano.group(1))
                if not (0 <= z <= 15):
                    raise ErrorPlano(f"{origen_fichero}:{numero}: el piso tiene que estar entre 0 y 15")
                if z in opciones["pisos"]:
                    raise ErrorPlano(f"{origen_fichero}:{numero}: el piso {z} está dos veces")
                piso = opciones["pisos"][z] = {"filas": [], "capas": {}, "linea": numero}
                actual = piso["filas"]
                capas = piso["capas"]
            continue
        if actual is not None:
            capa = re.fullmatch(r"\s*capa\s+(\S+)\s*:\s*", linea)
            if capa:
                nombre_capa = capa.group(1).lower()
                if nombre_capa not in CAPAS:
                    raise ErrorPlano(f"{origen_fichero}:{numero}: capa '{nombre_capa}' desconocida (hay: {', '.join(CAPAS)})")
                if nombre_capa in capas:
                    raise ErrorPlano(f"{origen_fichero}:{numero}: la capa '{nombre_capa}' está dos veces en el mismo plano")
                actual = capas[nombre_capa] = []
                continue
            if "\t" in linea:
                raise ErrorPlano(f"{origen_fichero}:{numero}: hay un tabulador en el plano; usa espacios")
            actual.append(linea.rstrip("\r\n"))
            continue
        limpia = linea.strip()
        if not limpia or limpia.startswith("#"):
            continue
        if ":" not in limpia:
            raise ErrorPlano(f"{origen_fichero}:{numero}: no entiendo '{limpia}' (falta 'clave: valor' o 'plano:')")
        clave, valor = (p.strip() for p in limpia.split(":", 1))
        clave = clave.lower()
        partes = clave.split()
        if len(partes) == 2 and partes[0] in ("zona", "objeto"):
            letra = linea.split(":", 1)[0].split()[1]
            if len(letra) != 1:
                raise ErrorPlano(f"{origen_fichero}:{numero}: '{partes[0]}' es para un solo carácter ({partes[0]} a: ...)")
            if partes[0] == "zona":
                opciones["zonas"][letra] = _leer_zona(valor, f"{origen_fichero}:{numero}")
            else:
                opciones["objetos"][letra] = _leer_objeto(valor, f"{origen_fichero}:{numero}")
            continue
        if len(partes) == 2 and partes[0] in ("cofre", "botin", "botín", "premios"):
            letra = linea.split(":", 1)[0].split()[1]
            if len(letra) != 1 or not (letra.isdigit() or "A" <= letra <= "Z") or letra in "EP":
                raise ErrorPlano(f"{origen_fichero}:{numero}: '{partes[0]}' es para una mayúscula o un número del plano "
                                 f"({partes[0]} C: ...)")
            cofre = opciones["cofres"].setdefault(letra, {"grupo": None, "botin": [], "premios": 1, "linea": numero})
            if partes[0] == "cofre":
                if len(valor) != 1 or not ("a" <= valor <= "z"):
                    raise ErrorPlano(f"{origen_fichero}:{numero}: 'cofre {letra}:' lleva la letra minúscula del grupo del jefe "
                                     f"(cofre {letra}: j)")
                cofre["grupo"] = valor
            elif partes[0] == "premios":
                if not valor.isdigit() or not (1 <= int(valor) <= 10):
                    raise ErrorPlano(f"{origen_fichero}:{numero}: los premios son cuántos objetos da el cofre, de 1 a 10")
                cofre["premios"] = int(valor)
            else:
                for trozo in valor.split(","):
                    botin = re.fullmatch(r"\s*(\d+)(?:\s*x\s*(\d+))?\s*", trozo, re.I)
                    if not botin or (botin.group(2) and not (1 <= int(botin.group(2)) <= 100)):
                        raise ErrorPlano(f"{origen_fichero}:{numero}: el botín es una lista de IDs con su cantidad si hace "
                                         f"falta, separados por comas (botin {letra}: 3043 x5, 7368)")
                    cofre["botin"].append((int(botin.group(1)), int(botin.group(2) or 1)))
            continue
        if len(partes) == 2 and partes[0] in ("destino", "punto", "subida"):
            letra = linea.split(":", 1)[0].split()[1]
            if len(letra) != 1 or not (letra.isdigit() or "A" <= letra <= "Z") or letra in "EP":
                raise ErrorPlano(f"{origen_fichero}:{numero}: '{partes[0]}' es para una mayúscula o un número del plano "
                                 f"({partes[0]} K: ...)")
            if partes[0] == "destino":
                opciones["destinos"][letra] = valor
            elif partes[0] == "subida":
                direccion = valor.lower()
                if direccion not in DIRECCIONES:
                    raise ErrorPlano(f"{origen_fichero}:{numero}: la subida va hacia {', '.join(DIRECCIONES)} "
                                     "(hacia donde se camina para subir)")
                opciones["subidas"][letra] = direccion
            else:
                if not valor.replace("_", "").isalnum() or not valor.isascii():
                    raise ErrorPlano(f"{origen_fichero}:{numero}: el nombre del punto solo puede llevar letras sin tilde, números y _")
                opciones["puntos"][letra] = valor.lower()
            continue
        if len(partes) == 2 and partes[0] in ("grupo", "radio"):
            letra = partes[1]
            if len(letra) != 1 or not ("a" <= letra <= "z"):
                raise ErrorPlano(f"{origen_fichero}:{numero}: el grupo tiene que ser una letra minúscula ({partes[0]} a: ...)")
            if partes[0] == "grupo":
                opciones["grupos"][letra] = valor
            else:
                if not valor.isdigit() or not (1 <= int(valor) <= 15):
                    raise ErrorPlano(f"{origen_fichero}:{numero}: el radio tiene que ser un número de casillas entre 1 y 15")
                opciones["radios"][letra] = int(valor)
            continue
        if partes and partes[0] == "exterior" and len(partes) <= 2:
            if len(partes) == 2 and not (partes[1].isdigit() and 0 <= int(partes[1]) <= 15):
                raise ErrorPlano(f"{origen_fichero}:{numero}: 'exterior 6: ...' lleva el número de un piso")
            opciones["exteriores"][int(partes[1]) if len(partes) == 2 else None] = valor.lower()
            continue
        if clave == "margen":
            if not valor.isdigit() or not (0 <= int(valor) <= 30):
                raise ErrorPlano(f"{origen_fichero}:{numero}: el margen es un número de casillas entre 0 y 30")
            opciones["margen"] = int(valor)
            continue
        if clave not in ("nombre", "origen", "suelo", "pared", "paredes_auto", "rampa"):
            raise ErrorPlano(f"{origen_fichero}:{numero}: opción desconocida '{clave}'")
        opciones[clave] = valor
    if filas is None:
        raise ErrorPlano(f"{origen_fichero}: falta la línea 'plano:' con el dibujo debajo")
    while filas and not filas[-1].strip():
        filas.pop()
    quitadas = 0
    while filas and not filas[0].strip():
        filas.pop(0)
        quitadas += 1
    if not filas:
        raise ErrorPlano(f"{origen_fichero}: el plano está vacío")
    # Cada capa (y cada plano de otro piso) va casilla a casilla con el plano principal tal como está
    # escrito, con sus filas en blanco de arriba: así una capa también llega a las paredes automáticas
    # de la fila de encima del dibujo, y los pisos quedan unos encima de otros.
    opciones["desplazamiento_capas"] = quitadas
    for clave in ("nombre", "origen", "suelo", "pared"):
        if clave not in opciones:
            raise ErrorPlano(f"{origen_fichero}: falta la opción '{clave}:'")
    return opciones, filas


def _leer_zona(valor, donde):
    """'suelo musgo, pared huesos' -> {"suelo": "musgo", "pared": "huesos"} (las dos son opcionales)."""
    zona = {}
    for trozo in valor.split(","):
        trozo = trozo.strip()
        if not trozo:
            continue
        tipo, _, material = trozo.partition(" ")
        tipo = tipo.lower()
        if tipo not in ("suelo", "pared", "rampa") or not material.strip():
            raise ErrorPlano(f"{donde}: una zona es 'suelo <material>', 'pared <material>' y/o 'rampa <material>', "
                             "separados por comas")
        if tipo in zona:
            raise ErrorPlano(f"{donde}: la zona dice dos veces '{tipo}'")
        zona[tipo] = material.strip().lower()
    if not zona:
        raise ErrorPlano(f"{donde}: zona vacía")
    return zona


def _leer_objeto(valor, donde):
    """'3114 3115 3116' (uno de ellos) o 'pared 5015 5016' (para pared horizontal y vertical)."""
    trozos = valor.split()
    en_pared = bool(trozos) and trozos[0].lower() == "pared"
    if en_pared:
        trozos = trozos[1:]
    if not trozos or not all(t.isdigit() for t in trozos):
        raise ErrorPlano(f"{donde}: un objeto es una lista de IDs (uno sale al azar) o 'pared <ID horizontal> <ID vertical>'")
    ids = [int(t) for t in trozos]
    if en_pared and len(ids) != 2:
        raise ErrorPlano(f"{donde}: un objeto de pared lleva dos IDs: el de la pared horizontal y el de la vertical")
    return {"ids": ids, "pared": en_pared}


def _orientacion(norte, oeste, este, sur, pared):
    """Pieza de pared según sus vecinas, con las mismas tablas que el RME (brush_tables.cpp)."""
    completa = {
        0b0000: "poste", 0b0001: "fin_sur", 0b0010: "fin_este", 0b0011: "esquina",
        0b0100: "fin_oeste", 0b0101: "diag_ne", 0b0110: "horizontal", 0b0111: "t_sur",
        0b1000: "fin_norte", 0b1001: "vertical", 0b1010: "diag_so", 0b1011: "t_este",
        0b1100: "diag_se", 0b1101: "t_oeste", 0b1110: "t_norte", 0b1111: "cruce",
    }
    media = {
        0b0000: "poste", 0b0001: "vertical", 0b0010: "horizontal", 0b0011: "esquina",
        0b0100: "poste", 0b0101: "vertical", 0b0110: "horizontal", 0b0111: "esquina",
        0b1000: "poste", 0b1001: "vertical", 0b1010: "horizontal", 0b1011: "esquina",
        0b1100: "poste", 0b1101: "vertical", 0b1110: "horizontal", 0b1111: "esquina",
    }
    mascara = (norte << 0) | (oeste << 1) | (este << 2) | (sur << 3)
    pieza = completa[mascara]
    if pieza not in pared:
        pieza = media[mascara]
    return pieza


def _suelo_en(x, y, piezas):
    """Elige una pieza de suelo con su peso, siempre la misma para la misma casilla."""
    total = sum(peso for _, peso in piezas)
    h = ((x * 73856093) ^ (y * 19349663)) & 0x7FFFFFFF
    h = (h * 2654435761) & 0xFFFFFFFF
    tirada = h % total
    for item_id, peso in piezas:
        if tirada < peso:
            return item_id
        tirada -= peso
    return piezas[0][0]


def _bordes(material_en, c, f, bordes):
    """Bordes de los suelos vecinos que tienen borde (agua, por ejemplo) sobre esta casilla, como el RME:
    lado (n, e, s, o), dos lados a la vez (dno, dne, dso, dse) o solo la esquina en diagonal (eno, ene, eso, ese).
    Como en el RME, solo se dibuja el borde del suelo de más "orden" sobre el de menos."""
    propio = material_en.get((c, f))
    orden_propio = bordes.get(propio, {}).get("orden", 0)
    items = []
    for material, piezas in sorted(bordes.items(), key=lambda kv: kv[1]["orden"]):
        if material == propio or piezas["orden"] <= orden_propio:
            continue
        items.extend(_piezas_borde(lambda dc, dr: material_en.get((c + dc, f + dr)) == material, piezas))
    return items


def _piezas_borde(hay, piezas):
    """Piezas de un borde del RME según en qué vecinas hay (hay(dc, dr) -> bool): lados, dos lados a la vez
    y esquinas sueltas."""
    es = {nombre: hay(dc, dr) for nombre, dc, dr in (("n", 0, -1), ("s", 0, 1), ("o", -1, 0), ("e", 1, 0),
                                                       ("no", -1, -1), ("ne", 1, -1), ("so", -1, 1), ("se", 1, 1))}
    items, usados = [], set()
    for a, b in (("n", "o"), ("n", "e"), ("s", "o"), ("s", "e")):
        if es[a] and es[b]:
            items.append(piezas["d" + a + b])
            usados.update((a, b))
    for lado in ("n", "e", "s", "o"):
        if es[lado] and lado not in usados:
            items.append(piezas[lado])
    for esquina in ("no", "ne", "so", "se"):
        if es[esquina] and not es[esquina[0]] and not es[esquina[1]]:
            items.append(piezas["e" + esquina])
    return items


def _variante(x, y, pieza):
    """Una pieza puede ser un ID o una lista de IDs (variantes): siempre la misma para la misma casilla."""
    if isinstance(pieza, list):
        return _suelo_en(x, y, [(item_id, 1) for item_id in pieza])
    return pieza


def generar(opciones, filas, materiales, origen_fichero="plano"):
    """Convierte un plano leído en (otbm.Map, info). info sirve para el .lua y para avisos."""
    nombre = opciones["nombre"]
    if not nombre.replace("_", "").isalnum() or not nombre.isascii() or nombre != nombre.lower():
        raise ErrorPlano(f"{origen_fichero}: el nombre '{nombre}' solo puede llevar minúsculas sin tilde, números y _")
    try:
        ox, oy, oz = (int(v) for v in opciones["origen"].replace(",", " ").split())
    except ValueError:
        raise ErrorPlano(f"{origen_fichero}: 'origen' tiene que ser tres números: X Y Z (por ejemplo 64000 64100 7)")
    if not (0 <= oz <= 15):
        raise ErrorPlano(f"{origen_fichero}: el piso Z tiene que estar entre 0 y 15")

    def suelo_de(nombre_suelo, donde):
        if nombre_suelo not in materiales["suelos"]:
            raise ErrorPlano(f"{donde}: suelo '{nombre_suelo}' desconocido. Hay: {', '.join(materiales['suelos'])}")
        return materiales["suelos"][nombre_suelo]

    def pared_de(nombre_pared, donde):
        if nombre_pared not in materiales["paredes"]:
            raise ErrorPlano(f"{donde}: pared '{nombre_pared}' desconocida. Hay: {', '.join(materiales['paredes'])}")
        pared = materiales["paredes"][nombre_pared]
        if "macizo" in pared:
            suelo_de(pared["macizo"], f"{donde}: macizo de la pared '{nombre_pared}'")
        return pared

    def rampa_de(nombre_rampa, donde):
        if nombre_rampa not in materiales.get("rampas", {}):
            raise ErrorPlano(f"{donde}: rampa '{nombre_rampa}' desconocida. Hay: {', '.join(materiales.get('rampas', {}))}")
        return materiales["rampas"][nombre_rampa]

    # Zona "por defecto" (la de las opciones suelo:, pared: y rampa:) y las de "zona X:".
    defecto = {"suelo": opciones["suelo"].lower(), "pared": opciones["pared"].lower(),
               "rampa": opciones.get("rampa", "piedra").lower()}
    zonas = {None: defecto}
    for letra, zona in opciones.get("zonas", {}).items():
        zonas[letra] = {**defecto, **zona}
    for letra, zona in zonas.items():
        donde = origen_fichero if letra is None else f"{origen_fichero}: zona {letra}"
        suelo_de(zona["suelo"], donde)
        pared_de(zona["pared"], donde)
        rampa_de(zona["rampa"], donde)
    objetos_def = opciones.get("objetos", {})
    juego = objetos_del_juego()
    for letra, obj in objetos_def.items():
        for item_id in obj["ids"]:
            if item_id not in juego:
                raise ErrorPlano(f"{origen_fichero}: objeto {letra}: el ID {item_id} no existe en el juego")
    auto = opciones.get("paredes_auto", "si").lower() in ("si", "sí", "s", "yes", "true", "1")
    subidas = opciones.get("subidas", {})
    for letra in subidas:
        if letra in opciones.get("destinos", {}) or letra in opciones.get("puntos", {}):
            raise ErrorPlano(f"{origen_fichero}: '{letra}' no puede ser a la vez una subida y un portal o un punto")
    for letra, cofre in opciones.get("cofres", {}).items():
        if letra in subidas or letra in opciones.get("destinos", {}):
            raise ErrorPlano(f"{origen_fichero}: '{letra}' no puede ser a la vez un cofre y una subida o un portal")
        if not cofre["grupo"]:
            raise ErrorPlano(f"{origen_fichero}: falta 'cofre {letra}: <letra del grupo del jefe>'")
        if not cofre["botin"]:
            raise ErrorPlano(f"{origen_fichero}: falta 'botin {letra}: ...' (qué objetos pueden salir del cofre)")
        for item_id, _ in cofre["botin"]:
            if item_id not in juego:
                raise ErrorPlano(f"{origen_fichero}: botin {letra}: el ID {item_id} no existe en el juego")
            if not juego[item_id].get("se_coge"):
                raise ErrorPlano(f"{origen_fichero}: botin {letra}: el ID {item_id} no se puede coger (no puede ser un premio)")

    # Pisos: el del plano principal y los de "plano 6:", "plano 8:"... Todos van casilla a casilla con
    # el plano principal (sus filas empiezan donde empezaría el plano principal con sus filas en blanco).
    desplazamiento = opciones.get("desplazamiento_capas", 0)
    pisos = [(oz, filas, 0, opciones.get("capas", {}))]
    for z, piso in sorted(opciones.get("pisos", {}).items()):
        if z == oz:
            raise ErrorPlano(f"{origen_fichero}: 'plano {z}:' es el piso del plano principal (el de 'origen')")
        pisos.append((z, piso["filas"], -desplazamiento, piso["capas"]))
    zs = [z for z, *_ in pisos]

    def donde_en(z, texto):
        return f"{origen_fichero}: {texto}" if z == oz else f"{origen_fichero}: piso {z}, {texto}"

    celdas = {}  # z -> {(col, fila): carácter}
    capa_zonas, capa_objetos = {}, {}

    def capa(z, capas, nombre_capa, definidas, que):
        dibujo = {}
        for f, linea in enumerate(capas.get(nombre_capa, []), start=-desplazamiento):
            for c, ch in enumerate(linea):
                if ch in VACIO:
                    continue
                if ch not in definidas:
                    raise ErrorPlano(donde_en(z, f"capa {nombre_capa}, fila {f + 1}, columna {c + 1}: '{ch}' no tiene '{que} {ch}:'"))
                dibujo[(c, f)] = ch
        return dibujo

    def transitable(ch):
        return ch is not None and ch not in "#+"

    for z, filas_piso, inicio, capas in pisos:
        dibujo = celdas[z] = {}
        for f, linea in enumerate(filas_piso, start=inicio):
            for c, ch in enumerate(linea):
                if ch in VACIO:
                    continue
                if not (ch in SUELO or ch.isdigit() or ("A" <= ch <= "Z") or ("a" <= ch <= "z")):
                    raise ErrorPlano(donde_en(z, f"fila {f + 1}, columna {c + 1}: no conozco el carácter '{ch}'"))
                dibujo[(c, f)] = ch
        if not dibujo:
            raise ErrorPlano(donde_en(z, "el plano de este piso está vacío"))
        capa_zonas[z] = capa(z, capas, "zonas", zonas, "zona")
        capa_objetos[z] = capa(z, capas, "objetos", objetos_def, "objeto")
        if auto:
            for (c, f), ch in list(dibujo.items()):
                if not transitable(ch):
                    continue
                for dc in (-1, 0, 1):
                    for dr in (-1, 0, 1):
                        vecina = (c + dc, f + dr)
                        if vecina not in dibujo:
                            dibujo[vecina] = "#"

    def zona_en(z, c, f):
        """La zona de la casilla; una pared sin zona dibujada toma la de un suelo vecino."""
        if (c, f) in capa_zonas[z]:
            return zonas[capa_zonas[z][(c, f)]]
        if celdas[z].get((c, f)) in ("#", "+"):
            for dc, dr in ((0, -1), (-1, 0), (1, 0), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)):
                vecina = (c + dc, f + dr)
                if transitable(celdas[z].get(vecina)) and vecina in capa_zonas[z]:
                    return zonas[capa_zonas[z][vecina]]
        return defecto

    def cueva_en(z, c, f):
        """La pared de cueva (borde de roca) de la casilla, si es una pared de una zona con 'pared: cueva ...'."""
        if celdas[z].get((c, f)) not in ("#", "+"):
            return None
        pared = materiales["paredes"][zona_en(z, c, f)["pared"]]
        return pared if "macizo" in pared else None

    # Paredes de cueva sin roca detrás (una pared de 1 o 2 casillas entre dos salas): son roca maciza,
    # y las de al lado ponen su borde mirando hacia ellas.
    macizas = {}
    for z in zs:
        macizas[z] = set()
        for (c, f), ch in celdas[z].items():
            if ch in ("#", "+") and cueva_en(z, c, f) and all(
                    (c + dc, f + dr) in celdas[z] for dc in (-1, 0, 1) for dr in (-1, 0, 1)):
                macizas[z].add((c, f))

    def roca_junto(z, c, f):
        """Para el exterior: la roca maciza de la cueva de al lado (detrás del borde de roca), si la hay."""
        for dc in (-1, 0, 1):
            for dr in (-1, 0, 1):
                pared = cueva_en(z, c + dc, f + dr)
                if pared:
                    return pared["macizo"]
        return None

    # Exterior: lo que rodea el dibujo (hasta 'margen' casillas más allá) se rellena con un suelo, para que
    # no se vea el fondo vacío. "exterior: tierra" vale para todos los pisos; "exterior 6: nada" lo quita en uno.
    margen = opciones.get("margen", MARGEN)
    todas = [cf for z in zs for cf in celdas[z]]
    c1, c2 = min(c for c, _ in todas) - margen, max(c for c, _ in todas) + margen
    f1, f2 = min(f for _, f in todas) - margen, max(f for _, f in todas) + margen
    exteriores = opciones.get("exteriores", {})
    exterior = {}  # z -> {(col, fila)} casillas de exterior
    material_fuera = {}  # z -> suelo del exterior
    for z in zs:
        material = exteriores.get(z, exteriores.get(None, "nada"))
        if material in ("nada", "ninguno", "no"):
            exterior[z] = set()
            continue
        suelo_de(material, donde_en(z, "exterior"))
        exterior[z] = {(c, f) for f in range(f1, f2 + 1) for c in range(c1, c2 + 1) if (c, f) not in celdas[z]}
        material_fuera[z] = material

    def material_exterior(z, cf):
        """El exterior toma la roca de la cueva de al lado, el suelo de la zona dibujada en la capa de zonas o,
        si no hay, el de 'exterior:'."""
        roca = roca_junto(z, *cf)
        if roca:
            return roca
        letra = capa_zonas[z].get(cf)
        return zonas[letra]["suelo"] if letra is not None else material_fuera[z]

    # Suelo de cada casilla que no es pared (las paredes no dan ni reciben bordes), también el exterior.
    material_en = {}
    for z in zs:
        material_en[z] = {cf: zona_en(z, *cf)["suelo"] for cf, ch in celdas[z].items() if ch not in "#+"}
        for cf in exterior[z]:
            material_en[z][cf] = material_exterior(z, cf)
    bordes = materiales.get("bordes", {})

    for z in zs:
        for (c, f) in capa_objetos[z]:
            if (c, f) not in celdas[z] and (c, f) not in exterior[z]:
                raise ErrorPlano(donde_en(z, f"capa objetos, fila {f + 1}, columna {c + 1}: hay un objeto fuera del mapa"))

    # Subidas: la rampa en este piso, su pie en la casilla de antes y, en el piso de arriba, la escalera de
    # bajada (un suelo) justo encima; al subir se sale a la casilla siguiente de arriba.
    poner = {}  # (z, col, fila) -> [IDs que se añaden]
    suelo_forzado = {}  # (z, col, fila) -> ID de suelo
    subidas_info = []
    for z in zs:
        for (c, f), ch in celdas[z].items():
            if ch not in subidas:
                continue
            dc, df = DIRECCIONES[subidas[ch]]
            donde = donde_en(z, f"fila {f + 1}, columna {c + 1}: la subida '{ch}'")
            if z - 1 not in celdas:
                raise ErrorPlano(f"{donde} necesita un 'plano {z - 1}:' (el piso de arriba)")
            arriba = celdas[z - 1]
            if arriba.get((c, f)) not in (".", "P"):
                raise ErrorPlano(f"{donde} necesita suelo libre ('.') justo encima, en el piso {z - 1}")
            if not transitable(arriba.get((c + dc, f + df))):
                raise ErrorPlano(f"{donde} necesita suelo en el piso {z - 1} hacia {subidas[ch]} (donde se sale al subir)")
            if not transitable(celdas[z].get((c - dc, f - df))):
                raise ErrorPlano(f"{donde} necesita suelo delante (de donde se viene para subir)")
            rampa = materiales["rampas"][zona_en(z, c, f)["rampa"]][subidas[ch]]
            poner.setdefault((z, c, f), []).append(rampa[0])
            poner.setdefault((z, c - dc, f - df), []).append(rampa[1])
            suelo_forzado[(z - 1, c, f)] = BAJADA
            subidas_info.append(((ox + c, oy + f, z), (ox + c + dc, oy + f + df, z - 1)))

    m = otbm.Map()
    m.description = f"Nocthold: {nombre} {MARCA}"
    m.monster_file = f"{nombre}-monster.xml"
    m.npc_file = f"{nombre}-npc.xml"
    m.house_file = f"{nombre}-house.xml"
    m.zone_file = f"{nombre}-zones.xml"

    puntos = []
    contadores = {}
    grupos = {}  # letra -> [(x, y, z), ...]
    marcas = {}  # mayúscula o número -> [(x, y, z), ...] (para los portales)
    extra = {}  # (x, y, z) -> {"objetos": [ids de decoración], "bloquea": bool}
    paredes = set()
    listadas = set()
    for z in zs:
        def es_muro(c, f):
            return celdas[z].get((c, f)) in ("#", "+")

        for (c, f) in sorted(set(celdas[z]) | exterior[z], key=lambda k: (k[1], k[0])):
            ch = celdas[z].get((c, f))
            x, y = ox + c, oy + f
            if not (0 <= x <= 65535 and 0 <= y <= 65535):
                raise ErrorPlano(f"{origen_fichero}: la casilla {x},{y} se sale del mapa (0-65535)")
            donde = donde_en(z, f"fila {f + 1}, columna {c + 1}")
            if ch is None:
                # Exterior: suelo, bordes y objetos, sin más comprobaciones (no se llega andando).
                t = otbm.Tile(x, y, z, ground=_suelo_en(x, y, materiales["suelos"][material_exterior(z, (c, f))]))
                t.items.extend(_bordes(material_en[z], c, f, bordes))
                if (c, f) in capa_objetos[z]:
                    obj = objetos_def[capa_objetos[z][(c, f)]]
                    if obj["pared"]:
                        raise ErrorPlano(f"{donde}: el objeto de pared '{capa_objetos[z][(c, f)]}' tiene que ir en una pared recta")
                    t.items.append(_variante(x, y, obj["ids"]))
                m.add(t)
                continue
            zona = zona_en(z, c, f)
            suelo = suelo_forzado.get((z, c, f)) or _suelo_en(x, y, materiales["suelos"][zona["suelo"]])
            t = otbm.Tile(x, y, z, ground=suelo)
            pieza = None
            cueva = cueva_en(z, c, f)
            if cueva:
                # Borde de roca (como las cuevas de Tibia): las piezas que miran a la roca maciza de detrás.
                if ch == "+":
                    raise ErrorPlano(f"{donde}: una pared de cueva no tiene puertas")
                piezas = [] if (c, f) in macizas[z] else _piezas_borde(
                    lambda dc, dr: (c + dc, f + dr) not in celdas[z] or (c + dc, f + dr) in macizas[z], cueva)
                if piezas:
                    t.items.extend(piezas)
                    paredes.add((x, y, z))
                else:
                    # Pared sin roca detrás: roca maciza (no se puede pisar), sin borde.
                    t.ground = _suelo_en(x, y, materiales["suelos"][cueva["macizo"]])
                    extra[(x, y, z)] = {"objetos": [], "bloquea": True}
                    listadas.add((x, y, z))
                    if (c, f) in capa_objetos[z]:
                        raise ErrorPlano(donde_en(z, f"capa objetos, fila {f + 1}, columna {c + 1}: no puede haber objetos en una pared de cueva"))
                    m.add(t)
                    continue
            elif ch in "#+":
                pared = materiales["paredes"][zona["pared"]]
                pieza = _orientacion(es_muro(c, f - 1), es_muro(c - 1, f), es_muro(c + 1, f), es_muro(c, f + 1), pared)
                if ch == "#":
                    t.items.append(_variante(x, y, pared[pieza]))
                else:
                    clave = {"horizontal": "puerta_horizontal", "vertical": "puerta_vertical"}.get(pieza)
                    if clave is None:
                        raise ErrorPlano(f"{donde}: la puerta tiene que estar en medio de una pared recta (pared a los dos lados)")
                    if clave not in pared:
                        raise ErrorPlano(f"{origen_fichero}: la pared '{zona['pared']}' no tiene puertas")
                    t.items.append(_variante(x, y, pared[clave]))
                paredes.add((x, y, z))
            elif ch == "P":
                t.flags |= otbm.FLAG_PROTECTIONZONE
            elif "a" <= ch <= "z":
                grupos.setdefault(ch, []).append((x, y, z))
            elif ch != "." and ch not in subidas:
                marcas.setdefault(ch, []).append((x, y, z))
                base = opciones.get("puntos", {}).get(ch) or {"E": "entrada", "J": "jefe"}.get(ch, ch.lower())
                contadores[base] = contadores.get(base, 0) + 1
                punto = base if contadores[base] == 1 else f"{base}{contadores[base]}"
                puntos.append((punto, x, y, z))
            decoracion = [] if ch in "#+" else _bordes(material_en[z], c, f, bordes)
            decoracion.extend(poner.get((z, c, f), []))
            if (c, f) in capa_objetos[z]:
                letra = capa_objetos[z][(c, f)]
                obj = objetos_def[letra]
                donde_obj = donde_en(z, f"capa objetos, fila {f + 1}, columna {c + 1}")
                if obj["pared"]:
                    if ch != "#" or pieza not in ("horizontal", "vertical"):
                        raise ErrorPlano(f"{donde_obj}: el objeto de pared '{letra}' tiene que ir en una pared recta")
                    decoracion.append(obj["ids"][0 if pieza == "horizontal" else 1])
                else:
                    if ch in "#+":
                        raise ErrorPlano(f"{donde_obj}: el objeto '{letra}' va en el suelo, no en una pared "
                                         "(para las paredes: 'objeto X: pared <ID horizontal> <ID vertical>')")
                    if (z, c, f) in suelo_forzado:
                        raise ErrorPlano(f"{donde_obj}: encima de una subida (la escalera de bajada) no puede haber objetos")
                    decoracion.append(_variante(x, y, obj["ids"]))
            t.items.extend(decoracion)
            # Casilla de suelo que no se puede pisar: agua profunda, una columna, una estatua...
            bloquea = juego.get(suelo, {}).get("bloquea", False) or any(juego[i]["bloquea"] for i in decoracion)
            if bloquea and ch not in "#+.P":
                raise ErrorPlano(f"{donde}: '{ch}' está en una casilla que no se puede pisar (suelo u objeto que bloquea el paso)")
            if bloquea and ((z, c, f) in poner or (z, c, f) in suelo_forzado):
                raise ErrorPlano(f"{donde}: una subida (o su pie, o la bajada de arriba) está en una casilla que no se puede pisar")
            if decoracion or (bloquea and ch not in "#+"):
                extra[(x, y, z)] = {"objetos": decoracion, "bloquea": bloquea or ch in "#+"}
            m.add(t)
            listadas.add((x, y, z))

    if contadores.get("entrada", 0) != 1:
        raise ErrorPlano(f"{origen_fichero}: el plano tiene que tener exactamente una E (entrada); tiene {contadores.get('entrada', 0)}")

    nombres = {p: (x, y, z) for p, x, y, z in puntos}
    portales = []
    for letra, valor in sorted(opciones.get("destinos", {}).items()):
        if letra not in marcas:
            raise ErrorPlano(f"{origen_fichero}: hay 'destino {letra}:' pero ninguna '{letra}' en el dibujo")
        partes_destino = valor.replace(",", " ").split()
        if valor.strip().lower() == "templo":
            destino = "templo"
        elif len(partes_destino) == 3 and all(p.isdigit() for p in partes_destino):
            destino = tuple(int(p) for p in partes_destino)
        elif valor.strip().lower() in nombres:
            destino = nombres[valor.strip().lower()]
        else:
            raise ErrorPlano(f"{origen_fichero}: 'destino {letra}: {valor}' no es 'templo', ni X Y Z, "
                             f"ni un punto de este mapa ({', '.join(sorted(nombres))})")
        for x, y, z in marcas[letra]:
            if destino == (x, y, z):
                raise ErrorPlano(f"{origen_fichero}: el portal '{letra}' te manda a su propia casilla")
            item = otbm.Item(PORTAL, aid=AID_TEMPLO) if destino == "templo" else otbm.Item(PORTAL, destino)
            m.tiles[(x, y, z)].items.append(item)
            portales.append((x, y, z, destino))

    for clave in ("grupos", "radios"):
        for letra in opciones.get(clave, {}):
            if letra not in grupos:
                raise ErrorPlano(f"{origen_fichero}: hay '{clave[:-1]} {letra}:' pero ninguna '{letra}' en el dibujo")
    # Pulls: cada mancha de monstruos (a 2 casillas o menos unos de otros, en el mismo piso) es un grupo que
    # se despierta entero. La letra solo dice qué monstruo es, así que un pull puede mezclar monstruos.
    todos = sorted(((z, y, x, letra) for letra, ps in grupos.items() for x, y, z in ps))
    padre = list(range(len(todos)))

    def raiz(i):
        while padre[i] != i:
            padre[i] = padre[padre[i]]
            i = padre[i]
        return i
    por_casilla = {(z, y, x): i for i, (z, y, x, _) in enumerate(todos)}
    for i, (z, y, x, _) in enumerate(todos):
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                j = por_casilla.get((z, y + dy, x + dx))
                if j is not None:
                    padre[raiz(i)] = raiz(j)
    manchas = {}
    for i in range(len(todos)):
        manchas.setdefault(raiz(i), []).append(todos[i])
    pulls = {}
    for numero, mancha in enumerate(sorted(manchas.values()), start=1):
        letras = sorted({letra for *_, letra in mancha})
        radios = [opciones.get("radios", {})[letra] for letra in letras if letra in opciones.get("radios", {})]
        pulls[str(numero)] = {"letras": letras, "radio": max(radios) if radios else None,
                              "monstruos": [(x, y, z, opciones.get("grupos", {}).get(letra)) for z, y, x, letra in mancha]}

    cofres = []
    for letra, cofre in sorted(opciones.get("cofres", {}).items()):
        if len(marcas.get(letra, [])) != 1:
            raise ErrorPlano(f"{origen_fichero}: el cofre '{letra}' tiene que estar exactamente una vez en el dibujo "
                             f"(está {len(marcas.get(letra, []))})")
        if cofre["grupo"] not in grupos:
            raise ErrorPlano(f"{origen_fichero}: 'cofre {letra}: {cofre['grupo']}' pero no hay ninguna '{cofre['grupo']}' "
                             "(el grupo del jefe) en el dibujo")
        del_jefe = [n for n, p in pulls.items() if cofre["grupo"] in p["letras"]]
        if len(del_jefe) != 1:
            raise ErrorPlano(f"{origen_fichero}: el jefe del cofre '{letra}' (la '{cofre['grupo']}') tiene que ser un solo pull, "
                             f"y está en {len(del_jefe)} sitios separados")
        x, y, z = marcas[letra][0]
        if (x, y, z) in extra:
            raise ErrorPlano(f"{origen_fichero}: el cofre '{letra}' necesita una casilla libre, sin objetos")
        cofres.append({"pos": (x, y, z), "grupo": del_jefe[0], "botin": cofre["botin"], "premios": cofre["premios"]})
    for letra in subidas:
        if not any(letra in celdas[z].values() for z in zs):
            raise ErrorPlano(f"{origen_fichero}: hay 'subida {letra}:' pero ninguna '{letra}' en el dibujo")

    m.waypoints = [(f"{nombre}.{p}", x, y, z) for p, x, y, z in puntos]
    xs = [t.x for t in m.tiles.values()]
    ys = [t.y for t in m.tiles.values()]
    m.width, m.height = max(xs) + 1, max(ys) + 1
    lx = [x for x, _, _ in listadas]
    ly = [y for _, y, _ in listadas]
    info = {
        "nombre": nombre,
        "caja": (min(lx), min(ly), max(lx), max(ly), oz),
        "ocupa": (min(xs), min(ys), max(xs), max(ys)),
        "pisos": sorted(zs),
        "puntos": puntos,
        "grupos": pulls,
        "portales": portales,
        "cofres": cofres,
        "subidas": subidas_info,
        "paredes_en": paredes,
        "listadas": listadas,
        "extra": extra,
        "suelos": len(listadas) - len(paredes),
        "paredes": len(paredes),
        "exterior": len(m.tiles) - len(listadas),
        "relleno": [z for z in sorted(zs) if exterior[z]],
    }
    return m, info


def _es_portal(item):
    return otbm.item_id(item) == PORTAL


def _solapan(a, b):
    """a y b: (x1, y1, x2, y2, [pisos]). Se pisan si comparten algún piso y sus rectángulos se tocan."""
    ax1, ay1, ax2, ay2, az = a
    bx1, by1, bx2, by2, bz = b
    return bool(set(az) & set(bz)) and ax1 <= bx2 and bx1 <= ax2 and ay1 <= by2 and by1 <= ay2


def ficheros_de(m, info, carpeta=SALIDA_MAPAS):
    """Todos los ficheros que genera un mapa: {ruta: bytes}."""
    nombre = info["nombre"]
    salida = {os.path.join(carpeta, f"{nombre}.otbm"): otbm.write(m)}
    for sufijo, raiz in (("monster", "monsters"), ("npc", "npcs"), ("house", "houses"), ("zones", "zones")):
        salida[os.path.join(carpeta, f"{nombre}-{sufijo}.xml")] = f'<?xml version="1.0"?>\n<{raiz} />\n'.encode()
    return salida


def lua_de(mapas):
    """data-nocthold/scripts/lib/nocthold_mapas.lua: lista de mapas y lo que debe haber en cada casilla."""
    lineas = [
        "-- GENERADO por tools/mapas/generar_mapa.py: no lo edites a mano (cambia el plano y vuelve a generar).",
        "-- Mapas de data-nocthold/world/custom/ hechos con el generador: puntos con nombre y, para la prueba",
        "-- automática (selftest.lua), lo que tiene que haber en cada casilla: {x, y, suelo, pared o 0, zona protegida}",
        "-- y, si tiene decoración o no se puede pisar: {..., {objetos de decoración}, bloquea el paso}.",
        "-- Las casillas de otro piso que el de z llevan z = N. El exterior (relleno de alrededor) no se lista.",
        "-- relleno: pisos con exterior, que llega hasta las esquinas de ocupa. subidas: {rampa, a dónde se sale arriba}.",
        "-- grupos: cada pull (mancha de monstruos del plano), con su radio de aggro y {x, y, z, monstruo} de cada uno.",
        "-- cofres: dónde aparece el cofre al morir entero su grupo (el jefe final), y qué puede dar ({ID, cantidad}).",
        "",
        "-- Se suma a Nocthold.mapas (puede haber otro fichero igual con mapas que no están en el repositorio).",
        "",
        "Nocthold = Nocthold or {}",
        "Nocthold.mapas = Nocthold.mapas or {}",
        "for nombre, mapa in pairs({",
    ]
    for m, info in mapas:
        x1, y1, x2, y2, z = info["caja"]
        lineas.append(f'\t["{info["nombre"]}"] = {{')
        lineas.append(f"\t\tz = {z}, caja = {{{x1}, {y1}, {x2}, {y2}}}, suelos = {info['suelos']}, paredes = {info['paredes']},")
        if len(info["pisos"]) > 1 or info["exterior"]:
            pisos = ", ".join(str(p) for p in info["pisos"])
            relleno = ", ".join(str(p) for p in info["relleno"])
            ox1, oy1, ox2, oy2 = info["ocupa"]
            lineas.append(f"\t\tpisos = {{{pisos}}}, exterior = {info['exterior']}, relleno = {{{relleno}}}, "
                          f"ocupa = {{{ox1}, {oy1}, {ox2}, {oy2}}},")
        lineas.append("\t\tpuntos = {")
        for p, x, y, zz in info["puntos"]:
            lineas.append(f'\t\t\t["{p}"] = {{{x}, {y}, {zz}}},')
        lineas.append("\t\t},")
        lineas.append("\t\tportales = {")
        for x, y, zz, destino in info["portales"]:
            d = '"templo"' if destino == "templo" else f"{{{destino[0]}, {destino[1]}, {destino[2]}}}"
            lineas.append(f"\t\t\t{{{x}, {y}, {zz}, destino = {d}}},")
        lineas.append("\t\t},")
        if info["subidas"]:
            lineas.append("\t\tsubidas = {")
            for (rx, ry, rz), (sx, sy, sz) in info["subidas"]:
                lineas.append(f"\t\t\t{{{{{rx}, {ry}, {rz}}}, {{{sx}, {sy}, {sz}}}}},")
            lineas.append("\t\t},")
        if info.get("cofres"):
            lineas.append("\t\tcofres = {")
            for cofre in info["cofres"]:
                x, y, zz = cofre["pos"]
                botin = ", ".join(f"{{{i}, {n}}}" for i, n in cofre["botin"])
                lineas.append(f'\t\t\t{{{x}, {y}, {zz}, grupo = "{cofre["grupo"]}", premios = {cofre["premios"]}, botin = {{{botin}}}}},')
            lineas.append("\t\t},")
        lineas.append("\t\tgrupos = {")
        for numero, g in info["grupos"].items():
            monstruos = ", ".join(f'{{{x}, {y}, {zz}, {chr(34) + nombre + chr(34) if nombre else "nil"}}}'
                                  for x, y, zz, nombre in g["monstruos"])
            radio = g["radio"] if g["radio"] else "nil"
            lineas.append(f'\t\t\t["{numero}"] = {{radio = {radio}, monstruos = {{{monstruos}}}}},')
        lineas.append("\t\t},")
        lineas.append("\t\tcasillas = {")
        for key in sorted(info["listadas"], key=lambda k: (k[2] != z, k[2], k[1], k[0])):
            t = m.tiles[key]
            otro_piso = "" if key[2] == z else f", z = {key[2]}"
            pz = "true" if t.flags & otbm.FLAG_PROTECTIONZONE else "false"
            objeto = otbm.item_id(t.items[0]) if key in info["paredes_en"] else 0
            extra = info["extra"].get(key)
            if extra:
                objetos = ", ".join(str(i) for i in extra["objetos"])
                bloquea = "true" if extra["bloquea"] else "false"
                lineas.append(f"\t\t\t{{{t.x}, {t.y}, {t.ground}, {objeto}, {pz}, {{{objetos}}}, {bloquea}{otro_piso}}},")
            else:
                lineas.append(f"\t\t\t{{{t.x}, {t.y}, {t.ground}, {objeto}, {pz}{otro_piso}}},")
        lineas.append("\t\t},")
        lineas.append("\t},")
    lineas.append("}) do")
    lineas.append("\tNocthold.mapas[nombre] = mapa")
    lineas.append("end")
    return ("\n".join(lineas) + "\n").encode()


def generar_todo(carpeta=PLANOS, salida_mapas=SALIDA_MAPAS, salida_lua=SALIDA_LUA):
    materiales = cargar_materiales()
    mapas = []
    planos = sorted(f for f in os.listdir(carpeta) if f.endswith(".txt"))
    if not planos:
        raise ErrorPlano(f"no hay planos (.txt) en {carpeta}")
    for fichero in planos:
        ruta = os.path.join(carpeta, fichero)
        with open(ruta, encoding="utf-8") as f:
            opciones, filas = leer_plano(f.read(), fichero)
        m, info = generar(opciones, filas, materiales, fichero)
        ocupa = (*info["ocupa"], info["pisos"])
        if _solapan(ocupa, ZONA_BUILDMAP):
            raise ErrorPlano(f"{fichero}: se mete en la sala de La Forja Caída (X 64000-64080, Y 64000-64030, Z 7)")
        for otro_m, otro in mapas:
            if otro["nombre"] == info["nombre"]:
                raise ErrorPlano(f"{fichero}: ya hay otro plano con el nombre '{info['nombre']}'")
            if _solapan(ocupa, (*otro["ocupa"], otro["pisos"])):
                raise ErrorPlano(f"{fichero}: se pisa con el mapa '{otro['nombre']}'; cambia el 'origen'")
        mapas.append((m, info))
    salida = {}
    for m, info in mapas:
        salida.update(ficheros_de(m, info, salida_mapas))
    salida[salida_lua] = lua_de(mapas)
    return mapas, salida


def main(argv=None):
    parser = argparse.ArgumentParser(description="Genera los mapas .otbm de Nocthold a partir de los planos de letras.")
    parser.add_argument("--comprobar", action="store_true",
                        help="no escribe nada: falla si lo generado no coincide con lo que hay en el repositorio")
    parser.add_argument("--planos", help="carpeta con los planos .txt (por defecto tools/mapas/planos)")
    parser.add_argument("--salida", help="carpeta donde escribir los mapas y el .lua, en vez de data-nocthold "
                                         "(para diseños que no van al repositorio público)")
    args = parser.parse_args(argv)
    salida_mapas, salida_lua = SALIDA_MAPAS, SALIDA_LUA
    if args.salida:
        salida_mapas = os.path.abspath(args.salida)
        salida_lua = os.path.join(salida_mapas, "nocthold_mapas_privados.lua")
    try:
        mapas, salida = generar_todo(os.path.abspath(args.planos) if args.planos else PLANOS, salida_mapas, salida_lua)
    except ErrorPlano as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    if args.comprobar:
        mal = [r for r, datos in salida.items() if not os.path.exists(r) or open(r, "rb").read() != datos]
        if mal:
            for r in mal:
                print(f"ERROR: {os.path.relpath(r, RAIZ)} no está al día con su plano.", file=sys.stderr)
            print("Ejecuta: python3 tools/mapas/generar_mapa.py y sube los cambios.", file=sys.stderr)
            return 1
        print(f"Mapas generados al día con sus planos: {len(mapas)}.")
        return 0

    os.makedirs(salida_mapas, exist_ok=True)
    for ruta, datos in salida.items():
        if not os.path.exists(ruta) or open(ruta, "rb").read() != datos:
            with open(ruta, "wb") as f:
                f.write(datos)
    for m, info in mapas:
        x1, y1, x2, y2, z = info["caja"]
        print(f"{info['nombre']}: {info['suelos']} casillas de suelo y {info['paredes']} de pared, "
              f"de {x1},{y1} a {x2},{y2} (pisos {', '.join(str(p) for p in info['pisos'])}; {info['exterior']} de exterior). Puntos: {', '.join(p for p, *_ in info['puntos'])}. "
              f"Grupos: {len(info['grupos'])} ({sum(len(g['monstruos']) for g in info['grupos'].values())} monstruos).")
    print(f"Escritos en {salida_mapas}/ y {salida_lua}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
