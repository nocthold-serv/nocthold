"""Lee data/items/appearances.dat (el catálogo de objetos del cliente 15.x, en protobuf).

Solo lo necesario para comprobar los materiales del generador: qué IDs de objeto existen,
cuáles son suelo ("bank") y cuáles bloquean el paso ("unpass"). Sin dependencias externas.
Campos: ver src/protobuf/appearances.proto.
"""


def _varint(buf, i):
    valor, desplazamiento = 0, 0
    while True:
        b = buf[i]
        i += 1
        valor |= (b & 0x7F) << desplazamiento
        if not b & 0x80:
            return valor, i
        desplazamiento += 7


def _campos(buf):
    """Recorre un mensaje protobuf: (número de campo, tipo, valor)."""
    i, n = 0, len(buf)
    while i < n:
        clave, i = _varint(buf, i)
        campo, tipo = clave >> 3, clave & 7
        if tipo == 0:
            valor, i = _varint(buf, i)
        elif tipo == 1:
            valor, i = buf[i:i + 8], i + 8
        elif tipo == 2:
            largo, i = _varint(buf, i)
            valor, i = buf[i:i + largo], i + largo
        elif tipo == 5:
            valor, i = buf[i:i + 4], i + 4
        else:
            raise ValueError(f"tipo protobuf {tipo} no soportado")
        yield campo, tipo, valor


def leer_objetos(ruta):
    """{id: {"suelo": bool, "bloquea": bool, "se_coge": bool}} de todos los objetos (no outfits ni efectos)."""
    with open(ruta, "rb") as f:
        datos = memoryview(f.read())
    objetos = {}
    for campo, tipo, valor in _campos(datos):
        if campo != 1 or tipo != 2:  # 1 = object
            continue
        info = {"suelo": False, "bloquea": False, "se_coge": False}
        ident = None
        for c, t, v in _campos(valor):
            if c == 1 and t == 0:
                ident = v
            elif c == 3 and t == 2:  # flags
                for fc, ft, fv in _campos(v):
                    if fc == 1:  # bank: es un suelo
                        info["suelo"] = True
                    elif fc == 13 and ft == 0 and fv:  # unpass
                        info["bloquea"] = True
                    elif fc == 18 and ft == 0 and fv:  # take: se puede coger y llevar encima
                        info["se_coge"] = True
        if ident is not None:
            objetos[ident] = info
    return objetos
