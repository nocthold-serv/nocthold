"""Pruebas del generador de mapas (sin servidor). Se lanzan con:
    python3 -m unittest discover -s tools/mapas -v
La prueba con el servidor de verdad la hace data-nocthold/scripts/nocthold/selftest.lua en GitHub.
"""

import collections
import json
import os
import re
import subprocess
import sys
import unittest

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import apariencias  # noqa: E402
import generar_mapa as gm  # noqa: E402
import otbm  # noqa: E402

RAIZ = gm.RAIZ
CANARY = os.path.join(RAIZ, "data-canary", "world", "canary.otbm")
CUSTOM_OTSERVBR = os.path.join(RAIZ, "data-otservbr-global", "world", "custom", "otservbr-custom.otbm")


def plano(dibujo, **extra):
    opciones = {"nombre": "prueba", "origen": "1000 1000 7", "suelo": "piedra gris", "pared": "piedra"}
    opciones.update(extra)
    cabecera = "".join(f"{k}: {v}\n" for k, v in opciones.items())
    return cabecera + "plano:\n" + dibujo


def generar(texto):
    opciones, filas = gm.leer_plano(texto)
    return gm.generar(opciones, filas, gm.cargar_materiales())


class FormatoOtbm(unittest.TestCase):
    def test_ida_y_vuelta(self):
        m, _ = generar(plano("#####\n#E.1#\n#+###\n"))
        leido = otbm.read(otbm.write(m))
        self.assertEqual(leido.tiles, m.tiles)
        self.assertEqual(leido.waypoints, m.waypoints)
        self.assertEqual(leido.monster_file, "prueba-monster.xml")
        self.assertEqual(leido.zone_file, "prueba-zones.xml")

    def test_escapes(self):
        # Coordenadas e IDs con bytes 0xFD, 0xFE y 0xFF: tienen que ir escapados.
        m = otbm.Map()
        m.width = m.height = 0xFFFF
        m.add(otbm.Tile(0xFDFE, 0xFEFF, 7, ground=0xFDFD, items=[0xFFFE], flags=0xFF))
        m.add(otbm.Tile(0xFDFF, 0xFEFD, 15, ground=0x00FE))
        m.waypoints = [("a", 0xFFFF, 0xFDFD, 0xFE)]
        datos = otbm.write(m)
        leido = otbm.read(datos)
        self.assertEqual(leido.tiles, m.tiles)
        self.assertEqual(leido.waypoints, m.waypoints)

    def test_mismo_plano_mismos_bytes(self):
        texto = plano("....\n.E..\n....\n", suelo="tierra de cueva")
        self.assertEqual(otbm.write(generar(texto)[0]), otbm.write(generar(texto)[0]))

    def test_lee_mapa_real_de_canary(self):
        # El lector entiende un mapa hecho con el RME de verdad (el mapa propio de otservbr).
        with open(CUSTOM_OTSERVBR, "rb") as f:
            m = otbm.read(f.read())
        self.assertGreater(len(m.tiles), 90000)
        self.assertEqual(m.monster_file, "otservbr-custom-monster.xml")
        self.assertEqual((m.version, m.items_major), (otbm.OTBM_VERSION, otbm.ITEMS_MAJOR))
        # Y lo vuelve a escribir sin perder casillas.
        self.assertEqual(otbm.read(otbm.write(m)).tiles, m.tiles)


class Plano(unittest.TestCase):
    def test_paredes_automaticas_y_orientacion(self):
        m, info = generar(plano("...\n.E.\n...\n"))
        self.assertEqual(info["suelos"], 9)
        self.assertEqual(info["paredes"], 16)
        pared = gm.cargar_materiales()["paredes"]["piedra"]
        t = lambda c, f: m.tiles[(1000 + c, 1000 + f, 7)].items  # noqa: E731
        self.assertEqual(t(-1, -1), [pared["poste"]])        # arriba a la izquierda
        self.assertEqual(t(1, -1), [pared["horizontal"]])    # arriba
        self.assertEqual(t(-1, 1), [pared["vertical"]])      # izquierda
        self.assertEqual(t(3, 3), [pared["esquina"]])        # abajo a la derecha
        self.assertEqual(t(1, 1), [])                        # suelo
        self.assertEqual(m.waypoints, [("prueba.entrada", 1001, 1001, 7)])

    def test_puertas_y_zona_protegida(self):
        m, _ = generar(plano("PPP\nPEP\n#+#\n.1.\n"))
        pared = gm.cargar_materiales()["paredes"]["piedra"]
        self.assertEqual(m.tiles[(1001, 1002, 7)].items, [pared["puerta_horizontal"]])
        self.assertTrue(m.tiles[(1000, 1000, 7)].flags & otbm.FLAG_PROTECTIONZONE)
        self.assertFalse(m.tiles[(1000, 1003, 7)].flags)
        m, _ = generar(plano("#.\n+E\n#.\n", paredes_auto="no"))
        self.assertEqual(m.tiles[(1000, 1001, 7)].items, [pared["puerta_vertical"]])

    def test_grupos_de_pull(self):
        _, info = generar(plano("E.aa.b\n.a....\n", **{"grupo a": "Sabueso de Ceniza", "radio b": "5"}))
        self.assertEqual(info["grupos"], {
            "a": {"monstruo": "Sabueso de Ceniza", "radio": None, "posiciones": [(1002, 1000, 7), (1003, 1000, 7), (1001, 1001, 7)]},
            "b": {"monstruo": None, "radio": 5, "posiciones": [(1005, 1000, 7)]},
        })
        self.assertEqual(info["suelos"], 12)  # los monstruos van sobre suelo normal

    def test_portales(self):
        m, info = generar(plano("ES.T\n..K.\n", **{"destino S": "templo", "destino T": "jefe1", "punto K": "jefe1"}))
        salida = m.tiles[(1001, 1000, 7)].items
        self.assertEqual(salida, [otbm.Item(gm.PORTAL, aid=gm.AID_TEMPLO)])
        self.assertEqual(m.tiles[(1003, 1000, 7)].items, [otbm.Item(gm.PORTAL, (1002, 1001, 7))])
        self.assertEqual(info["portales"], [(1001, 1000, 7, "templo"), (1003, 1000, 7, (1002, 1001, 7))])
        self.assertEqual(info["paredes"], 16)  # los portales no cuentan como pared
        leido = otbm.read(otbm.write(m))
        self.assertEqual(leido.tiles, m.tiles)
        _, info = generar(plano("ET\n", **{"destino T": "100 200 7"}))
        self.assertEqual(info["portales"], [(1001, 1000, 7, (100, 200, 7))])
        with self.assertRaises(gm.ErrorPlano):
            generar(plano("ET\n", **{"destino T": "a ninguna parte"}))

    def test_zonas_de_suelo_y_pared(self):
        # La capa de zonas va casilla a casilla con el plano; una pared sin zona toma la de su suelo vecino.
        texto = plano("\nE..\n...\n", **{"zona h": "suelo fango negro, pared huesos", "zona m": "suelo musgo"})
        texto += "capa zonas:\n\nhh\n  m\n"
        m, info = generar(texto)
        mats = gm.cargar_materiales()
        fango = {i for i, _ in mats["suelos"]["fango negro"]}
        musgo = {i for i, _ in mats["suelos"]["musgo"]}
        huesos = set(mats["paredes"]["huesos"]["horizontal"]) | {mats["paredes"]["huesos"]["esquina"]}
        self.assertIn(m.tiles[(1000, 1000, 7)].ground, fango)
        self.assertIn(m.tiles[(1001, 1000, 7)].ground, fango)
        self.assertEqual(m.tiles[(1002, 1000, 7)].ground, 429)  # sin zona: el suelo por defecto
        self.assertIn(m.tiles[(1002, 1001, 7)].ground, musgo)
        self.assertIn(m.tiles[(1000, 999, 7)].items[0], huesos)  # pared encima de una casilla de fango
        self.assertEqual(m.tiles[(1003, 999, 7)].items, [1295])  # pared de la esquina: piedra (no toca zona)

    def test_objetos_de_decoracion(self):
        # 3114 son huesos (se pisan), 5015/5016 una calavera colgada en pared horizontal/vertical,
        # 13149 una columna (no se pisa).
        # La fila en blanco de arriba y el espacio de la izquierda dejan sitio a las paredes automáticas,
        # y la capa de objetos llega a ellas.
        texto = plano("\n E...\n ....\n", **{"objeto b": "3114", "objeto c": "pared 5015 5016", "objeto k": "13149"})
        texto += "capa objetos:\n  c\nc\n   bk\n"
        m, info = generar(texto)
        self.assertEqual(m.tiles[(1002, 999, 7)].items, [1295, 5015])  # pared horizontal + calavera
        self.assertEqual(m.tiles[(1000, 1000, 7)].items, [1294, 5016])  # pared vertical + calavera
        self.assertEqual(m.tiles[(1003, 1001, 7)].items, [3114])
        self.assertEqual(m.tiles[(1004, 1001, 7)].items, [13149])
        self.assertEqual(info["extra"][(1003, 1001, 7)], {"objetos": [3114], "bloquea": False})
        self.assertEqual(info["extra"][(1004, 1001, 7)], {"objetos": [13149], "bloquea": True})
        self.assertEqual(info["suelos"], 8)  # los objetos no convierten el suelo en pared
        lua = gm.lua_de([(m, info)]).decode()
        self.assertIn("{1004, 1001, 429, 0, false, {13149}, true}", lua)
        self.assertIn("{1003, 1001, 429, 0, false, {3114}, false}", lua)
        self.assertIn("{1002, 999, 429, 1295, false, {5015}, true}", lua)
        self.assertEqual(otbm.read(otbm.write(m)).tiles, m.tiles)
        with self.assertRaises(gm.ErrorPlano) as e:  # la calavera de pared en el suelo
            generar(plano("E..\n", **{"objeto c": "pared 5015 5016"}) + "capa objetos:\n c\n")
        self.assertIn("pared recta", str(e.exception))
        with self.assertRaises(gm.ErrorPlano) as e:  # una columna encima de la entrada
            generar(plano("E..\n", **{"objeto k": "13149"}) + "capa objetos:\nk\n")
        self.assertIn("no se puede pisar", str(e.exception))
        with self.assertRaises(gm.ErrorPlano) as e:
            generar(plano("E..\n") + "capa objetos:\n z\n")
        self.assertIn("no tiene 'objeto z:'", str(e.exception))

    def test_suelo_que_no_se_pisa_y_bordes(self):
        m, info = generar(plano("E...\n", **{"zona w": "suelo agua negra"}) + "capa zonas:\n   w\n")
        self.assertEqual(info["extra"][(1003, 1000, 7)], {"objetos": [], "bloquea": True})
        # La orilla del agua negra (borde del RME) cae en la casilla de al lado, y tampoco se pisa.
        bordes = gm.cargar_materiales()["bordes"]["agua negra"]
        self.assertEqual(info["extra"][(1002, 1000, 7)], {"objetos": [bordes["e"]], "bloquea": True})
        self.assertNotIn((1001, 1000, 7), info["extra"])
        # Barro alrededor de un charco: el agua (más "orden") pinta su borde sobre el barro, no al revés.
        m, info = generar(plano("E...\n", suelo="fango negro", **{"zona w": "suelo agua negra"}) + "capa zonas:\n   w\n")
        self.assertEqual(info["extra"][(1003, 1000, 7)], {"objetos": [], "bloquea": True})
        self.assertEqual(info["extra"][(1002, 1000, 7)]["objetos"], [bordes["e"]])
        with self.assertRaises(gm.ErrorPlano) as e:
            generar(plano("E.\n", **{"zona w": "suelo agua negra"}) + "capa zonas:\n w\n")
        self.assertIn("no se puede pisar", str(e.exception))

    def test_puntos_repetidos_y_letras(self):
        _, info = generar(plano("EJJ1N\n"))
        self.assertEqual([p for p, *_ in info["puntos"]], ["entrada", "jefe", "jefe2", "1", "n"])
        _, info = generar(plano("EKJ\n", **{"punto K": "jefe_final"}))
        self.assertEqual([p for p, *_ in info["puntos"]], ["entrada", "jefe_final", "jefe"])

    def test_errores_claros(self):
        casos = {
            plano("....\n"): "exactamente una E",
            plano("E..\nE..\n"): "exactamente una E",
            plano("E.*\n"): "no conozco el carácter '*'",
            plano("E.a\n", **{"grupo b": "Sabueso"}): "ninguna 'b'",
            plano("E.a\n", **{"radio a": "0"}): "entre 1 y 15",
            plano("E\t.\n"): "tabulador",
            plano("E.+.\n", paredes_auto="no"): "puerta",
            plano("E.\n", suelo="lava"): "suelo 'lava' desconocido",
            plano("E.\n", nombre="Forja Caída"): "minúsculas",
            plano("E.\n", origen="1 2"): "tres números",
            "nombre: a\norigen: 1 1 7\nsuelo: piedra\npared: piedra\n": "falta la línea 'plano:'",
        }
        for texto, mensaje in casos.items():
            with self.subTest(mensaje=mensaje):
                with self.assertRaises(gm.ErrorPlano) as e:
                    generar(texto)
                self.assertIn(mensaje, str(e.exception))

    def test_no_pisa_la_sala_de_buildmap(self):
        self.assertTrue(gm._solapan((64010, 63990, 64020, 64001, 7), gm.ZONA_BUILDMAP))
        self.assertFalse(gm._solapan((64010, 63990, 64020, 64001, 6), gm.ZONA_BUILDMAP))


class Materiales(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.objetos = apariencias.leer_objetos(os.path.join(RAIZ, "data", "items", "appearances.dat"))
        with open(os.path.join(AQUI, "materiales.json"), encoding="utf-8") as f:
            cls.materiales = json.load(f)

    def test_suelos_existen_y_son_suelo(self):
        for nombre, piezas in self.materiales["suelos"].items():
            for item_id, peso in piezas:
                with self.subTest(suelo=nombre, id=item_id):
                    self.assertIn(item_id, self.objetos)
                    self.assertTrue(self.objetos[item_id]["suelo"])
                    self.assertGreater(peso, 0)

    def test_paredes_existen_y_bloquean(self):
        for nombre, piezas in self.materiales["paredes"].items():
            for pieza in ("horizontal", "vertical", "esquina", "poste"):
                self.assertIn(pieza, piezas, f"a la pared '{nombre}' le falta la pieza {pieza}")
            for pieza, ids in piezas.items():
                for item_id in ids if isinstance(ids, list) else [ids]:
                    with self.subTest(pared=nombre, pieza=pieza, id=item_id):
                        self.assertIn(item_id, self.objetos)
                        self.assertTrue(self.objetos[item_id]["bloquea"])
                        self.assertFalse(self.objetos[item_id]["suelo"])

    def test_puertas_abribles_sin_llave(self):
        # data/libs/tables/doors.lua dice qué puertas son "cerradas con llave" (lockedDoor):
        # esas no las abre nadie sin llave, así que el generador no puede usarlas.
        with open(os.path.join(RAIZ, "data", "libs", "tables", "doors.lua"), encoding="utf-8") as f:
            texto = f.read()
        con_llave = {int(x) for x in re.findall(r"lockedDoor\s*=\s*(\d+)", texto)}
        cerradas = {int(x) for x in re.findall(r"closedDoor\s*=\s*(\d+)", texto)}
        self.assertTrue(con_llave)
        for nombre, piezas in self.materiales["paredes"].items():
            for pieza, item_id in piezas.items():
                if pieza.startswith("puerta"):
                    with self.subTest(pared=nombre, pieza=pieza):
                        self.assertNotIn(item_id, con_llave, "es una puerta cerrada con llave")
                        self.assertIn(item_id, cerradas)

    def test_orientacion_como_en_el_mapa_de_canary(self):
        # En canary.otbm (hecho a mano con el RME) miramos qué pieza de pared de piedra
        # usaron en cada forma básica, y tiene que ser la misma que elige el generador.
        with open(CANARY, "rb") as f:
            m = otbm.read(f.read())
        pared = self.materiales["paredes"]["piedra"]
        familia = set(range(1294, 1305)) | {6248, 6249, 6250, 6251, 6252, 6253}

        def es_pared(k):
            t = m.tiles.get(k)
            return bool(t and any(i in familia for i in t.items))

        usadas = collections.defaultdict(collections.Counter)
        for (x, y, z), t in m.tiles.items():
            for i in t.items:
                if i in familia:
                    vecinas = (es_pared((x, y - 1, z)), es_pared((x - 1, y, z)), es_pared((x + 1, y, z)), es_pared((x, y + 1, z)))
                    usadas[vecinas][i] += 1
        for vecinas in ((False, True, True, False), (True, False, False, True), (True, True, False, False), (False, False, True, True)):
            with self.subTest(vecinas=vecinas):
                esperada = usadas[vecinas].most_common(1)[0][0]
                self.assertEqual(pared[gm._orientacion(*vecinas, pared)], esperada)


class Repositorio(unittest.TestCase):
    def test_lo_generado_esta_al_dia(self):
        r = subprocess.run([sys.executable, os.path.join(AQUI, "generar_mapa.py"), "--comprobar"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
