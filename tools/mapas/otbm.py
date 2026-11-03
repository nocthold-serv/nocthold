"""Lectura y escritura de mapas .otbm (el formato de mapas de Canary y de RME).

Solo usa la biblioteca estándar de Python. Lo justo para lo que necesita Nocthold:
casillas con suelo, objetos sin atributos (paredes, puertas...), marcas de zona
(zona protegida, no-logout), puntos con nombre (waypoints) y los nombres de los
ficheros de monstruos, NPC, casas y zonas que acompañan al mapa.

Formato (resumen; ver src/io/iomap.cpp de Canary):
  "OTBM" + nodo raíz {versión, ancho, alto, versión de objetos}
    nodo MAP_DATA {atributos: descripción, ficheros}
      nodo TILE_AREA {x, y, z base (múltiplos de 256)}
        nodo TILE {dx, dy, [flags], [suelo]}
          nodo ITEM {id}
      nodo TOWNS {nodo TOWN...}
      nodo WAYPOINTS {nodo WAYPOINT {nombre, x, y, z}...}
Un nodo empieza con 0xFE + tipo y acaba con 0xFF. Dentro de un nodo, cualquier byte
0xFD, 0xFE o 0xFF de datos va precedido de 0xFD (escape).
"""

import struct

NODE_ESC, NODE_START, NODE_END = 0xFD, 0xFE, 0xFF

# Tipos de nodo (src/io/io_definitions.hpp)
OTBM_ROOT = 0
OTBM_MAP_DATA = 2
OTBM_TILE_AREA = 4
OTBM_TILE = 5
OTBM_ITEM = 6
OTBM_TOWNS = 12
OTBM_TOWN = 13
OTBM_HOUSETILE = 14
OTBM_WAYPOINTS = 15
OTBM_WAYPOINT = 16

# Atributos
ATTR_DESCRIPTION = 1
ATTR_TILE_FLAGS = 3
ATTR_ACTION_ID = 4
ATTR_UNIQUE_ID = 5
ATTR_ITEM = 9
ATTR_EXT_SPAWN_MONSTER_FILE = 11
ATTR_EXT_HOUSE_FILE = 13
ATTR_EXT_SPAWN_NPC_FILE = 23
ATTR_EXT_ZONE_FILE = 24

# Marcas de casilla
FLAG_PROTECTIONZONE = 1 << 0
FLAG_NOPVPZONE = 1 << 2
FLAG_NOLOGOUT = 1 << 3
FLAG_PVPZONE = 1 << 4

# Cabecera: las mismas versiones que escribe el RME de opentibiabr para Canary 15.x
OTBM_VERSION = 2
ITEMS_MAJOR = 3
ITEMS_MINOR = 57


class Tile:
    __slots__ = ("x", "y", "z", "ground", "items", "flags", "house_id")

    def __init__(self, x, y, z, ground=None, items=None, flags=0, house_id=0):
        self.x, self.y, self.z = x, y, z
        self.ground = ground
        self.items = list(items or [])
        self.flags = flags
        self.house_id = house_id

    def key(self):
        return (self.x, self.y, self.z)

    def __eq__(self, other):
        return (self.key(), self.ground, self.items, self.flags, self.house_id) == (
            other.key(), other.ground, other.items, other.flags, other.house_id)

    def __repr__(self):
        return f"Tile({self.x},{self.y},{self.z} suelo={self.ground} objetos={self.items} flags={self.flags})"


class Map:
    def __init__(self):
        self.version = OTBM_VERSION
        self.width = 0
        self.height = 0
        self.items_major = ITEMS_MAJOR
        self.items_minor = ITEMS_MINOR
        self.description = ""
        self.monster_file = ""
        self.npc_file = ""
        self.house_file = ""
        self.zone_file = ""
        self.tiles = {}  # (x, y, z) -> Tile
        self.towns = []  # (id, nombre, x, y, z)
        self.waypoints = []  # (nombre, x, y, z)

    def add(self, tile):
        self.tiles[tile.key()] = tile
        return tile


# --------------------------------------------------------------------------- escribir

class _Writer:
    def __init__(self):
        self.out = bytearray()

    def start(self, node_type):
        self.out.append(NODE_START)
        self.out.append(node_type)

    def end(self):
        self.out.append(NODE_END)

    def raw(self, data):
        for b in data:
            if b in (NODE_ESC, NODE_START, NODE_END):
                self.out.append(NODE_ESC)
            self.out.append(b)

    def u8(self, v):
        self.raw(struct.pack("<B", v))

    def u16(self, v):
        self.raw(struct.pack("<H", v))

    def u32(self, v):
        self.raw(struct.pack("<I", v))

    def string(self, s):
        data = s.encode("ascii")  # Canary lee el texto sin escapes: solo ASCII
        self.u16(len(data))
        self.raw(data)


def write(m):
    """Devuelve los bytes del .otbm. Mismo mapa -> mismos bytes (orden fijo)."""
    w = _Writer()
    w.out += b"OTBM"
    w.start(OTBM_ROOT)
    w.u32(m.version)
    w.u16(m.width)
    w.u16(m.height)
    w.u32(m.items_major)
    w.u32(m.items_minor)

    w.start(OTBM_MAP_DATA)
    if m.description:
        w.u8(ATTR_DESCRIPTION)
        w.string(m.description)
    for attr, value in ((ATTR_EXT_SPAWN_MONSTER_FILE, m.monster_file),
                        (ATTR_EXT_SPAWN_NPC_FILE, m.npc_file),
                        (ATTR_EXT_HOUSE_FILE, m.house_file),
                        (ATTR_EXT_ZONE_FILE, m.zone_file)):
        if value:
            w.u8(attr)
            w.string(value)

    areas = {}
    for key in sorted(m.tiles, key=lambda k: (k[2], k[1], k[0])):
        t = m.tiles[key]
        areas.setdefault((t.x & 0xFF00, t.y & 0xFF00, t.z), []).append(t)
    for (bx, by, bz) in sorted(areas, key=lambda a: (a[2], a[1], a[0])):
        w.start(OTBM_TILE_AREA)
        w.u16(bx)
        w.u16(by)
        w.u8(bz)
        for t in areas[(bx, by, bz)]:
            if t.house_id:
                w.start(OTBM_HOUSETILE)
                w.u8(t.x - bx)
                w.u8(t.y - by)
                w.u32(t.house_id)
            else:
                w.start(OTBM_TILE)
                w.u8(t.x - bx)
                w.u8(t.y - by)
            if t.flags:
                w.u8(ATTR_TILE_FLAGS)
                w.u32(t.flags)
            if t.ground:
                w.u8(ATTR_ITEM)
                w.u16(t.ground)
            for item_id in t.items:
                w.start(OTBM_ITEM)
                w.u16(item_id)
                w.end()
            w.end()
        w.end()

    w.start(OTBM_TOWNS)
    for town_id, name, x, y, z in m.towns:
        w.start(OTBM_TOWN)
        w.u32(town_id)
        w.string(name)
        w.u16(x)
        w.u16(y)
        w.u8(z)
        w.end()
    w.end()

    w.start(OTBM_WAYPOINTS)
    for name, x, y, z in m.waypoints:
        w.start(OTBM_WAYPOINT)
        w.string(name)
        w.u16(x)
        w.u16(y)
        w.u8(z)
        w.end()
    w.end()

    w.end()  # MAP_DATA
    w.end()  # raíz
    return bytes(w.out)


# --------------------------------------------------------------------------- leer

class Node:
    __slots__ = ("type", "data", "children")

    def __init__(self, node_type):
        self.type = node_type
        self.data = bytearray()
        self.children = []


def _parse_nodes(buf):
    """Convierte los bytes (sin la cabecera de 4) en un árbol de nodos sin escapes."""
    if not buf or buf[0] != NODE_START:
        raise ValueError("el fichero no empieza por un nodo")
    root = None
    stack = []
    i, n = 0, len(buf)
    while i < n:
        b = buf[i]
        if b == NODE_START:
            if i + 1 >= n:
                raise ValueError("nodo cortado al final del fichero")
            node = Node(buf[i + 1])
            if stack:
                stack[-1].children.append(node)
            elif root is None:
                root = node
            else:
                raise ValueError("hay datos después del nodo raíz")
            stack.append(node)
            i += 2
        elif b == NODE_END:
            if not stack:
                raise ValueError("fin de nodo sin nodo abierto")
            stack.pop()
            i += 1
        elif b == NODE_ESC:
            if i + 1 >= n or not stack:
                raise ValueError("escape mal formado")
            stack[-1].data.append(buf[i + 1])
            i += 2
        else:
            if not stack:
                raise ValueError("datos fuera de cualquier nodo")
            stack[-1].data.append(b)
            i += 1
    if stack:
        raise ValueError(f"faltan {len(stack)} finales de nodo")
    return root


class _Reader:
    def __init__(self, data):
        self.data = bytes(data)
        self.pos = 0

    def left(self):
        return len(self.data) - self.pos

    def take(self, fmt):
        size = struct.calcsize(fmt)
        if self.pos + size > len(self.data):
            raise ValueError("faltan datos")
        (v,) = struct.unpack_from(fmt, self.data, self.pos)
        self.pos += size
        return v

    def u8(self):
        return self.take("<B")

    def u16(self):
        return self.take("<H")

    def u32(self):
        return self.take("<I")

    def string(self):
        length = self.u16()
        s = self.data[self.pos:self.pos + length]
        if len(s) != length:
            raise ValueError("texto cortado")
        self.pos += length
        return s.decode("latin-1")


def _item_id(node, where):
    r = _Reader(node.data)
    item_id = r.u16()
    # Los atributos de objeto (acción, texto, destino...) se ignoran: no los usamos.
    for child in node.children:
        if child.type != OTBM_ITEM:
            raise ValueError(f"{where}: nodo {child.type} dentro de un objeto")
    return item_id


def read(data):
    """Lee los bytes de un .otbm y devuelve un Map. Lanza ValueError si está mal formado."""
    if len(data) < 6:
        raise ValueError("fichero demasiado corto")
    root = _parse_nodes(data[4:])
    m = Map()
    r = _Reader(root.data)
    m.version = r.u32()
    m.width = r.u16()
    m.height = r.u16()
    m.items_major = r.u32()
    m.items_minor = r.u32()
    if m.version > 5:
        raise ValueError("versión de OTBM desconocida")
    if m.items_major < 3:
        raise ValueError("mapa demasiado antiguo para Canary")

    map_data = [c for c in root.children if c.type == OTBM_MAP_DATA]
    if len(map_data) != 1:
        raise ValueError("falta el nodo MAP_DATA")
    md = map_data[0]
    r = _Reader(md.data)
    while r.left():
        attr = r.u8()
        value = r.string()
        if attr == ATTR_DESCRIPTION:
            m.description = value
        elif attr == ATTR_EXT_SPAWN_MONSTER_FILE:
            m.monster_file = value
        elif attr == ATTR_EXT_SPAWN_NPC_FILE:
            m.npc_file = value
        elif attr == ATTR_EXT_HOUSE_FILE:
            m.house_file = value
        elif attr == ATTR_EXT_ZONE_FILE:
            m.zone_file = value
        else:
            raise ValueError(f"atributo de mapa desconocido {attr}")

    seen_towns = seen_waypoints = False
    for node in md.children:
        if node.type == OTBM_TILE_AREA:
            if seen_towns:
                raise ValueError("zona de casillas después de las ciudades")
            r = _Reader(node.data)
            bx, by, bz = r.u16(), r.u16(), r.u8()
            for tn in node.children:
                if tn.type not in (OTBM_TILE, OTBM_HOUSETILE):
                    raise ValueError(f"nodo {tn.type} donde iba una casilla")
                r = _Reader(tn.data)
                t = Tile(bx + r.u8(), by + r.u8(), bz)
                where = f"casilla {t.x},{t.y},{t.z}"
                if tn.type == OTBM_HOUSETILE:
                    t.house_id = r.u32()
                while r.left():
                    attr = r.u8()
                    if attr == ATTR_TILE_FLAGS:
                        t.flags = r.u32()
                    elif attr == ATTR_ITEM:
                        t.ground = r.u16()
                    else:
                        raise ValueError(f"{where}: atributo {attr} desconocido")
                for child in tn.children:
                    if child.type == OTBM_ITEM:
                        t.items.append(_item_id(child, where))
                    elif child.type == 19:  # OTBM_TILE_ZONE: lo aceptamos pero no lo guardamos
                        continue
                    else:
                        raise ValueError(f"{where}: nodo {child.type} desconocido")
                m.add(t)
        elif node.type == OTBM_TOWNS:
            seen_towns = True
            for town in node.children:
                r = _Reader(town.data)
                m.towns.append((r.u32(), r.string(), r.u16(), r.u16(), r.u8()))
        elif node.type == OTBM_WAYPOINTS:
            seen_waypoints = True
            for wp in node.children:
                r = _Reader(wp.data)
                m.waypoints.append((r.string(), r.u16(), r.u16(), r.u8()))
        else:
            raise ValueError(f"nodo {node.type} desconocido en MAP_DATA")
    if not seen_towns or not seen_waypoints:
        raise ValueError("faltan los nodos de ciudades o de waypoints (Canary los exige)")
    return m
