#!/usr/bin/env python3
"""Dibuja los iconos de nuestros 30 hechizos (originales, hechos con código).

Uso:  python client/hechizos/dibujar_iconos.py      (necesita Pillow: pip install pillow)

Escribe en esta carpeta:
  * iconos-32.png  tira de 32x32 por hechizo (barra de acciones, lista de hechizos)
  * iconos-20.png  tira de 20x20 por hechizo (ventana de enfriamientos)
  * muestra.png    los 30 iconos en grande con su nombre, para revisarlos

El orden de la tira es el de ORDEN (el mismo que los ids 1001-1030 del servidor):
el icono del hechizo con id 1001+i está en la posición i. Si añades un hechizo,
ponlo AL FINAL de ORDEN, dale su dibujo en DIBUJOS y vuelve a ejecutar esto.

No usamos iconos de Tibia ni de ningún otro juego: cada icono es un fondo del
color de la clase, un marco del color del tipo (ataque rojo, curación verde,
apoyo azul) y un símbolo sencillo dibujado aquí.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CARPETA = Path(__file__).resolve().parent

# Mismo orden que los ids del servidor (1001 + posición). No reordenar.
ORDEN = [
    "Shield Bash", "Sundering Strike", "Iron Sweep", "Taunting Roar", "Groundbreaker",
    "Fortress Stance", "Intercept", "Bulwark", "Last Stand", "Guardian's Oath",
    "Verdant Touch", "Renewing Roots", "Purify", "Blooming Wave", "Lifebloom",
    "Spirit Bloom", "Rebirth", "Thorn Lash", "Nature's Grasp", "Barkskin",
    "Arcane Bolt", "Shatter", "Frost Lattice", "Prismatic Burst", "Arcane Nova",
    "Meteor", "Chain Lightning", "Frost Armor", "Mana Ward", "Arcane Surge",
]

S = 128  # se dibuja a 128 px y se reduce: así los bordes salen suaves
C = S / 2

# Fondo de cada clase (centro, borde)
CLASE = {
    "guardian": ((120, 104, 82), (34, 28, 22)),
    "custodio": ((58, 112, 56), (14, 32, 16)),
    "arcanista": ((92, 64, 150), (20, 14, 44)),
}
# Marco según el tipo de hechizo
MARCO = {"ataque": (196, 62, 44), "curacion": (86, 196, 92), "apoyo": (74, 140, 220)}

ACERO = (206, 212, 222)
ACERO_OSC = (110, 118, 130)
ORO = (232, 190, 84)
ORO_OSC = (150, 106, 34)
MADERA = (130, 86, 46)
HOJA = (120, 210, 96)
HOJA_OSC = (40, 120, 46)
FLOR = (244, 150, 196)
BLANCO = (250, 250, 250)
HIELO = (170, 226, 255)
HIELO_OSC = (70, 150, 210)
ENERGIA = (200, 150, 255)
ENERGIA_CLARA = (240, 220, 255)
FUEGO = (255, 150, 40)
FUEGO_CLARO = (255, 230, 120)
ROJO = (220, 60, 40)


# ---------------------------------------------------------------- utilidades
def rot(puntos, ang, cx=C, cy=C):
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in puntos]


def estrella(cx, cy, r_ext, r_int, puntas, ang=-90):
    pts = []
    for i in range(puntas * 2):
        r = r_ext if i % 2 == 0 else r_int
        a = math.radians(ang + i * 180 / puntas)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def escudo_pts(cx, cy, w, h):
    # escudo de cometa: arriba recto, abajo en punta
    pts = [(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2)]
    for i in range(0, 11):
        t = i / 10
        pts.append((cx + w / 2 * (1 - t ** 1.6), cy - h / 2 + h * 0.45 + h * 0.55 * t))
    for i in range(10, -1, -1):
        t = i / 10
        pts.append((cx - w / 2 * (1 - t ** 1.6), cy - h / 2 + h * 0.45 + h * 0.55 * t))
    return pts


def escudo(d, cx, cy, w, h, relleno=ACERO, borde=ACERO_OSC, cruz=None):
    pts = escudo_pts(cx, cy, w, h)
    d.polygon(pts, fill=relleno, outline=borde)
    d.line(pts + [pts[0]], fill=borde, width=5, joint="curve")
    if cruz:
        d.line([(cx, cy - h / 2 + 8), (cx, cy + h / 2 - 12)], fill=cruz, width=8)
        d.line([(cx - w / 2 + 8, cy - h / 6), (cx + w / 2 - 8, cy - h / 6)], fill=cruz, width=8)


def espada(d, x1, y1, x2, y2, hoja=ACERO, guarda=ORO, ancho=10):
    d.line([(x1, y1), (x2, y2)], fill=hoja, width=ancho)
    # punta
    ang = math.atan2(y2 - y1, x2 - x1)
    px, py = x2 + math.cos(ang) * 10, y2 + math.sin(ang) * 10
    nx, ny = -math.sin(ang) * ancho / 2, math.cos(ang) * ancho / 2
    d.polygon([(x2 + nx, y2 + ny), (px, py), (x2 - nx, y2 - ny)], fill=hoja)
    # guarda y empuñadura
    gx, gy = x1 + math.cos(ang) * 6, y1 + math.sin(ang) * 6
    d.line([(gx + nx * 3, gy + ny * 3), (gx - nx * 3, gy - ny * 3)], fill=guarda, width=8)
    d.line([(x1, y1), (x1 - math.cos(ang) * 16, y1 - math.sin(ang) * 16)], fill=MADERA, width=8)


def rayo(d, pts, color, ancho=10, brillo=None):
    if brillo:
        d.line(pts, fill=brillo, width=ancho + 8, joint="curve")
    d.line(pts, fill=color, width=ancho, joint="curve")


def hoja(d, cx, cy, largo, ancho, ang, color=HOJA, nervio=HOJA_OSC):
    pts = []
    for i in range(21):
        t = i / 20
        pts.append((cx - largo / 2 + largo * t, cy - math.sin(math.pi * t) * ancho / 2))
    for i in range(20, -1, -1):
        t = i / 20
        pts.append((cx - largo / 2 + largo * t, cy + math.sin(math.pi * t) * ancho / 2))
    d.polygon(rot(pts, ang, cx, cy), fill=color)
    d.line(rot([(cx - largo / 2, cy), (cx + largo / 2, cy)], ang, cx, cy), fill=nervio, width=3)


def flor(d, cx, cy, r, petalos, color=FLOR, centro=FUEGO_CLARO):
    for i in range(petalos):
        a = math.radians(i * 360 / petalos)
        px, py = cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55
        d.ellipse([px - r * 0.42, py - r * 0.42, px + r * 0.42, py + r * 0.42], fill=color)
    d.ellipse([cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3], fill=centro)


def gota(d, cx, cy, r, color):
    d.ellipse([cx - r, cy - r * 0.2, cx + r, cy + r * 1.8], fill=color)
    d.polygon([(cx - r * 0.92, cy + r * 0.5), (cx, cy - r * 1.4), (cx + r * 0.92, cy + r * 0.5)], fill=color)


def copo(d, cx, cy, r, color, ancho=6):
    for i in range(6):
        a = math.radians(i * 60 - 90)
        x2, y2 = cx + math.cos(a) * r, cy + math.sin(a) * r
        d.line([(cx, cy), (x2, y2)], fill=color, width=ancho)
        for s in (-1, 1):
            mx, my = cx + math.cos(a) * r * 0.6, cy + math.sin(a) * r * 0.6
            b = a + s * math.radians(40)
            d.line([(mx, my), (mx + math.cos(b) * r * 0.3, my + math.sin(b) * r * 0.3)], fill=color, width=ancho - 2)


def arco(d, caja, ini, fin, color, ancho):
    d.arc(caja, ini, fin, fill=color, width=ancho)


def resplandor(img, color, radio=18, fuerza=150):
    """Halo suave detrás de lo dibujado en img (capa RGBA)."""
    alfa = img.split()[3].filter(ImageFilter.GaussianBlur(radio))
    alfa = alfa.point(lambda v: min(255, v * fuerza // 100))
    halo = Image.new("RGBA", img.size, color + (0,))
    halo.putalpha(alfa)
    return Image.alpha_composite(halo, img)


# ---------------------------------------------------------------- dibujos
# Cada dibujo recibe un ImageDraw sobre una capa transparente de 128x128.
def d_shield_bash(d):
    escudo(d, 58, 62, 62, 76, cruz=ORO)
    for i, y in enumerate((36, 60, 84)):  # líneas de impacto
        d.line([(100, y), (118, y - 6 + i * 6)], fill=BLANCO, width=6)


def d_sundering_strike(d):
    espada(d, 30, 98, 92, 34, ancho=11)
    d.line([(36, 40), (96, 100)], fill=ROJO, width=7)  # tajo
    d.line([(44, 36), (100, 92)], fill=FUEGO_CLARO, width=3)


def d_iron_sweep(d):
    arco(d, [16, 16, 112, 112], 200, 520, ACERO, 12)
    arco(d, [30, 30, 98, 98], 220, 500, ACERO_OSC, 6)
    espada(d, 50, 78, 96, 30, ancho=9)


def d_taunting_roar(d):
    d.polygon([(26, 46), (52, 50), (52, 78), (26, 82)], fill=ORO)  # boca/cuerno
    for i, r in enumerate((24, 38, 52)):
        arco(d, [52 - r, 64 - r, 52 + r, 64 + r], -45, 45, (255, 220 - i * 50, 120 - i * 30), 8)


def d_groundbreaker(d):
    d.rectangle([10, 84, 118, 118], fill=(98, 72, 50))
    rayo(d, [(64, 84), (54, 96), (68, 104), (58, 118)], (30, 20, 12), 6)
    rayo(d, [(64, 84), (82, 98), (76, 110), (92, 118)], (30, 20, 12), 5)
    d.rectangle([56, 18, 72, 62], fill=MADERA)  # mango del martillo
    d.rectangle([34, 54, 94, 82], fill=ACERO, outline=ACERO_OSC, width=4)


def d_fortress_stance(d):
    d.rectangle([28, 44, 100, 108], fill=ACERO, outline=ACERO_OSC, width=4)
    for x in (28, 52, 76):
        d.rectangle([x, 26, x + 24 - 6, 46], fill=ACERO, outline=ACERO_OSC, width=4)
    d.rectangle([54, 74, 74, 108], fill=(60, 50, 40))


def d_intercept(d):
    escudo(d, 76, 64, 46, 58, cruz=ORO)
    for y, l in ((40, 44), (64, 56), (88, 44)):
        d.line([(50 - l, y), (46, y)], fill=BLANCO, width=6)


def d_bulwark(d):
    escudo(d, 64, 64, 84, 96, relleno=ORO, borde=ORO_OSC)
    escudo(d, 64, 60, 52, 62, relleno=ACERO, borde=ACERO_OSC)


def d_last_stand(d):
    d.line([(64, 112), (64, 24)], fill=MADERA, width=8)  # asta
    d.polygon([(68, 24), (110, 34), (68, 48)], fill=ROJO)  # bandera
    escudo(d, 54, 78, 46, 52, cruz=ORO)


def d_guardians_oath(d):
    d.polygon(estrella(64, 60, 44, 18, 4), fill=ORO, outline=ORO_OSC)
    d.ellipse([46, 42, 82, 78], outline=BLANCO, width=6)
    d.line([(40, 110), (88, 110)], fill=ORO, width=6)


def d_verdant_touch(d):
    hoja(d, 64, 60, 84, 44, -40)
    d.line([(36, 96), (52, 80)], fill=HOJA_OSC, width=6)
    d.polygon(estrella(94, 34, 12, 4, 4), fill=BLANCO)


def d_renewing_roots(d):
    for dx, ang in ((-30, 200), (0, 260), (30, 330)):
        arco(d, [44 + dx, 70, 84 + dx, 120], ang - 70, ang + 40, MADERA, 8)
    d.line([(64, 92), (64, 40)], fill=HOJA_OSC, width=8)
    hoja(d, 50, 44, 34, 18, -30)
    hoja(d, 78, 36, 34, 18, -150)


def d_purify(d):
    gota(d, 64, 46, 28, HIELO)
    d.ellipse([52, 56, 66, 70], fill=BLANCO)
    for cx, cy in ((26, 30), (102, 40), (96, 98)):
        d.polygon(estrella(cx, cy, 12, 4, 4), fill=BLANCO)


def d_blooming_wave(d):
    for i, y in enumerate((88, 70)):
        pts = [(10 + x, y + math.sin(x / 14 + i) * 8) for x in range(0, 110, 4)]
        d.line(pts, fill=(HOJA if i else HOJA_OSC), width=10, joint="curve")
    flor(d, 40, 46, 22, 5)
    flor(d, 86, 36, 18, 5, color=(250, 200, 230))


def d_lifebloom(d):
    d.line([(64, 116), (64, 64)], fill=HOJA_OSC, width=8)
    hoja(d, 44, 92, 34, 16, -20)
    flor(d, 64, 52, 40, 6)


def d_spirit_bloom(d):
    flor(d, 64, 64, 46, 8, color=(200, 240, 255), centro=BLANCO)
    for i in range(3):
        a = math.radians(-90 + i * 120)
        cx, cy = 64 + math.cos(a) * 48, 64 + math.sin(a) * 48
        d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=BLANCO)


def d_rebirth(d):
    arco(d, [22, 22, 106, 106], 20, 320, ORO, 10)
    d.polygon([(100, 36), (116, 56), (90, 60)], fill=ORO)  # flecha del círculo
    d.line([(64, 92), (64, 50)], fill=HOJA, width=8)
    hoja(d, 50, 52, 28, 16, -40)
    hoja(d, 78, 48, 28, 16, -140)


def d_thorn_lash(d):
    # látigo de espinas en forma de S
    pts = [(20 + t * 0.88, 64 + math.sin(t / 100 * 2 * math.pi) * 30) for t in range(0, 101, 2)]
    d.line(pts, fill=MADERA, width=10, joint="curve")
    for i in range(4, len(pts) - 2, 6):
        (x0, y0), (x1, y1) = pts[i - 1], pts[i + 1]
        ang = math.atan2(y1 - y0, x1 - x0)
        nx, ny = -math.sin(ang), math.cos(ang)
        x, y = pts[i]
        for s in (-1, 1):
            d.polygon([(x - math.cos(ang) * 6, y - math.sin(ang) * 6), (x + nx * 16 * s, y + ny * 16 * s),
                       (x + math.cos(ang) * 6, y + math.sin(ang) * 6)], fill=HOJA)
    d.ellipse([100, 70, 120, 90], fill=HOJA)


def d_natures_grasp(d):
    for dx in (-30, 0, 30):
        pts = [(64 + dx + math.sin(t / 10 + dx) * 10, 118 - t) for t in range(0, 84, 4)]
        d.line(pts, fill=HOJA, width=9, joint="curve")
        x, y = pts[-1]
        arco(d, [x - 14, y - 4, x + 14, y + 24], 180, 360, HOJA, 8)
    d.ellipse([48, 52, 80, 84], outline=(240, 240, 200), width=5)


def d_barkskin(d):
    escudo(d, 64, 64, 76, 90, relleno=MADERA, borde=(70, 44, 22))
    for x in (46, 64, 82):
        d.line([(x, 30), (x + 4, 60), (x - 2, 92)], fill=(84, 54, 28), width=5, joint="curve")
    hoja(d, 92, 30, 30, 16, -30)


def d_arcane_bolt(d):
    # proyectil de energía en forma de rombo con estela
    for i, (w, col) in enumerate(((26, ENERGIA), (14, ENERGIA_CLARA))):
        d.line([(22, 106), (76, 52)], fill=col, width=w - i * 4)
    d.polygon(rot([(64, 30), (84, 64), (64, 98), (44, 64)], 45, 82, 46), fill=ENERGIA)
    d.polygon(rot([(82, 30), (92, 46), (82, 62), (72, 46)], 45, 82, 46), fill=BLANCO)


def d_shatter(d):
    for ang, l in ((0, 50), (60, 36), (130, 42), (200, 34), (270, 46), (320, 30)):
        pts = rot([(64, 64 - 6), (64 + l, 64), (64, 64 + 6)], ang)
        d.polygon(pts, fill=HIELO, outline=HIELO_OSC)
    d.ellipse([54, 54, 74, 74], fill=BLANCO)


def d_frost_lattice(d):
    for i in range(-2, 3):
        d.line([(64 + i * 22 - 40, 24), (64 + i * 22 + 40, 104)], fill=HIELO_OSC, width=5)
        d.line([(64 + i * 22 + 40, 24), (64 + i * 22 - 40, 104)], fill=HIELO_OSC, width=5)
    copo(d, 64, 64, 34, HIELO, 8)


def d_prismatic_burst(d):
    d.polygon([(64, 22), (100, 92), (28, 92)], fill=(220, 230, 255), outline=BLANCO)
    for i, col in enumerate(((255, 80, 80), (255, 200, 60), (90, 220, 120), (80, 160, 255), (190, 110, 255))):
        y = 72 + i * 8
        d.line([(84, y - 8), (122, y + 4 + i * 4)], fill=col, width=6)


def d_arcane_nova(d):
    d.polygon(estrella(64, 64, 54, 22, 8), fill=ENERGIA)
    d.polygon(estrella(64, 64, 34, 14, 8, ang=-67.5), fill=ENERGIA_CLARA)
    d.ellipse([52, 52, 76, 76], fill=BLANCO)


def d_meteor(d):
    for i, w in enumerate((30, 22, 14)):
        d.line([(110 - i * 4, 18 + i * 2), (62, 66)], fill=(FUEGO, FUEGO_CLARO, BLANCO)[i] if i else FUEGO, width=w)
    d.ellipse([28, 50, 76, 98], fill=(110, 60, 40), outline=FUEGO, width=6)
    d.ellipse([40, 62, 52, 74], fill=(70, 36, 24))


def d_chain_lightning(d):
    nodos = [(20, 30), (52, 58), (40, 80), (78, 72), (70, 100), (108, 96)]
    rayo(d, nodos, ENERGIA_CLARA, 7, brillo=ENERGIA)
    for x, y in (nodos[0], nodos[3], nodos[5]):
        d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=BLANCO)


def d_frost_armor(d):
    escudo(d, 64, 64, 76, 90, relleno=(120, 190, 240), borde=HIELO_OSC)
    copo(d, 64, 58, 24, BLANCO, 6)


def d_mana_ward(d):
    d.ellipse([18, 18, 110, 110], outline=ENERGIA, width=10)
    d.ellipse([34, 34, 94, 94], outline=ENERGIA_CLARA, width=5)
    d.polygon(estrella(64, 64, 22, 9, 4, ang=-45), fill=BLANCO)


def d_arcane_surge(d):
    for i, x in enumerate((26, 52, 78)):
        col = (ENERGIA, ENERGIA_CLARA, BLANCO)[i]
        d.polygon([(x, 30), (x + 26, 64), (x, 98), (x + 10, 64)], fill=col)


DIBUJOS = {
    "Shield Bash": ("guardian", "ataque", d_shield_bash),
    "Sundering Strike": ("guardian", "ataque", d_sundering_strike),
    "Iron Sweep": ("guardian", "ataque", d_iron_sweep),
    "Taunting Roar": ("guardian", "ataque", d_taunting_roar),
    "Groundbreaker": ("guardian", "ataque", d_groundbreaker),
    "Fortress Stance": ("guardian", "apoyo", d_fortress_stance),
    "Intercept": ("guardian", "apoyo", d_intercept),
    "Bulwark": ("guardian", "apoyo", d_bulwark),
    "Last Stand": ("guardian", "apoyo", d_last_stand),
    "Guardian's Oath": ("guardian", "apoyo", d_guardians_oath),
    "Verdant Touch": ("custodio", "curacion", d_verdant_touch),
    "Renewing Roots": ("custodio", "curacion", d_renewing_roots),
    "Purify": ("custodio", "curacion", d_purify),
    "Blooming Wave": ("custodio", "curacion", d_blooming_wave),
    "Lifebloom": ("custodio", "curacion", d_lifebloom),
    "Spirit Bloom": ("custodio", "curacion", d_spirit_bloom),
    "Rebirth": ("custodio", "curacion", d_rebirth),
    "Thorn Lash": ("custodio", "ataque", d_thorn_lash),
    "Nature's Grasp": ("custodio", "ataque", d_natures_grasp),
    "Barkskin": ("custodio", "apoyo", d_barkskin),
    "Arcane Bolt": ("arcanista", "ataque", d_arcane_bolt),
    "Shatter": ("arcanista", "ataque", d_shatter),
    "Frost Lattice": ("arcanista", "ataque", d_frost_lattice),
    "Prismatic Burst": ("arcanista", "ataque", d_prismatic_burst),
    "Arcane Nova": ("arcanista", "ataque", d_arcane_nova),
    "Meteor": ("arcanista", "ataque", d_meteor),
    "Chain Lightning": ("arcanista", "ataque", d_chain_lightning),
    "Frost Armor": ("arcanista", "apoyo", d_frost_armor),
    "Mana Ward": ("arcanista", "apoyo", d_mana_ward),
    "Arcane Surge": ("arcanista", "apoyo", d_arcane_surge),
}


def fondo(clase):
    centro, borde = CLASE[clase]
    img = Image.new("RGB", (S, S), borde)
    px = img.load()
    for y in range(S):
        for x in range(S):
            t = min(1.0, math.hypot(x - C * 0.85, y - C * 0.8) / (S * 0.75))
            px[x, y] = tuple(int(centro[i] * (1 - t) + borde[i] * t) for i in range(3))
    return img.convert("RGBA")


def icono(nombre):
    clase, tipo, dibujo = DIBUJOS[nombre]
    img = fondo(clase)
    capa = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dibujo(ImageDraw.Draw(capa))
    capa = resplandor(capa, (0, 0, 0), radio=6, fuerza=160)  # sombra para que se lea sobre el fondo
    img = Image.alpha_composite(img, capa)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, S - 1, S - 1], outline=(10, 10, 10), width=4)
    d.rectangle([4, 4, S - 5, S - 5], outline=MARCO[tipo], width=6)
    return img.convert("RGB")


def main():
    faltan = [n for n in ORDEN if n not in DIBUJOS]
    sobran = [n for n in DIBUJOS if n not in ORDEN]
    if faltan or sobran or len(set(ORDEN)) != len(ORDEN):
        sys.exit(f"ERROR: ORDEN y DIBUJOS no cuadran (faltan {faltan}, sobran {sobran})")
    grandes = [icono(n) for n in ORDEN]
    for tam in (32, 20):
        tira = Image.new("RGB", (tam * len(ORDEN), tam))
        for i, img in enumerate(grandes):
            tira.paste(img.resize((tam, tam), Image.LANCZOS), (i * tam, 0))
        tira.save(CARPETA / f"iconos-{tam}.png", optimize=True)

    # Muestra para revisar: 10 por fila, a 64 px y a tamaño real
    col, celda = 10, 120
    muestra = Image.new("RGB", (col * celda, 3 * (celda + 10)), (24, 24, 28))
    d = ImageDraw.Draw(muestra)
    fuente = ImageFont.load_default()
    for i, (nombre, img) in enumerate(zip(ORDEN, grandes)):
        x, y = (i % col) * celda + 10, (i // col) * (celda + 10) + 8
        muestra.paste(img.resize((64, 64), Image.LANCZOS), (x, y))
        muestra.paste(img.resize((32, 32), Image.LANCZOS), (x + 70, y))
        muestra.paste(img.resize((20, 20), Image.LANCZOS), (x + 70, y + 40))
        d.text((x, y + 70), nombre[:18], fill=(230, 230, 230), font=fuente)
        d.text((x, y + 84), f"id {1001 + i}", fill=(150, 150, 150), font=fuente)
    muestra.save(CARPETA / "muestra.png", optimize=True)
    print(f"{len(ORDEN)} iconos -> iconos-32.png, iconos-20.png y muestra.png")


if __name__ == "__main__":
    main()
