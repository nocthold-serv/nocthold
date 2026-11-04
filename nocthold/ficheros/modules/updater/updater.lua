-- Actualizador de Nocthold: sustituye a modules/updater/updater.lua de OTClient
-- (lo copia ahí client/configurar.py). Basado en el de OTClient Redemption
-- (licencia MIT), con estos cambios:
--
--  * Lee una lista estática (GET de un .json en GitHub) en vez de llamar a un
--    PHP con POST: así no hace falta montar nada en el VPS.
--  * Solo calcula la huella (crc32) de los ficheros de la lista, no de todo lo
--    que ve el cliente (que incluye los gráficos de %APPDATA%, cientos de MB).
--  * Nunca toca el .exe (sin firmar, Windows bloquearía uno nuevo).
--  * Si algo falla (sin internet, GitHub caído...) no bloquea: lo apunta en el
--    log y el cliente arranca con lo que tiene.
--  * Si ya intentó instalar esta misma versión y al volver a arrancar sigue
--    igual, no lo reintenta en bucle.
--
-- Formato de la lista (la genera client/manifiesto.py):
--   { "version": "...", "url": "https://.../", "files": { "/init.lua": "crc32", ... } }

Updater = {}

local REINTENTOS_DESCARGA = 3
local ESPERA_LISTA = 10      -- segundos para bajar la lista
local ESPERA_FICHERO = 30    -- segundos por fichero
local MARCA = "/actualizador.txt" -- en la carpeta de usuario: última versión intentada

local ventana
local cargarModulos
local evento
local operacion = 0

local function log(texto)
  g_logger.info("[Actualizador] " .. texto)
end

local function terminar()
  if HTTP and HTTP.cancel and operacion ~= 0 then
    HTTP.cancel(operacion)
  end
  operacion = 0
  removeEvent(evento)
  evento = nil
  if ventana then
    ventana:destroy()
    ventana = nil
  end
  if cargarModulos then
    local f = cargarModulos
    cargarModulos = nil
    f()
  end
end

-- Sigue arrancando sin actualizar.
local function fallo(motivo)
  g_logger.warning("[Actualizador] " .. motivo .. " (se arranca sin actualizar)")
  terminar()
end

local function leerMarca()
  local ok, texto = pcall(g_resources.readFileContents, MARCA)
  if ok and type(texto) == "string" then
    return texto:match("^%s*(.-)%s*$")
  end
  return ""
end

local function escribirMarca(version)
  pcall(g_resources.writeFileContents, MARCA, version)
end

-- Como HTTP.get / HTTP.download, pero con nuestro tiempo de espera (HTTP.timeout
-- es de 2 s, poco para una conexión lenta).
local function pedir(url, segundos, callback)
  local id = g_http.get(url, segundos)
  HTTP.operations[id] = { type = "get", json = true, url = url, callback = callback }
  return id
end

local function descargar(url, fichero, segundos, callback, progreso)
  local id = g_http.download(url, fichero, segundos)
  HTTP.operations[id] = {
    type = "download", url = url, file = fichero, callback = callback, progressCallback = progreso
  }
  return id
end

local function texto(id, valor)
  if ventana and ventana[id] then
    ventana[id]:setText(valor)
  end
end

local function porcentaje(id, valor)
  if ventana and ventana[id] then
    ventana[id]:setPercent(valor)
  end
end

local function bajarFicheros(base, lista, i, intentos, alTerminar)
  if not ventana then return end
  local entrada = lista[i]
  if not entrada then
    return alTerminar()
  end
  local fichero, huella = entrada[1], entrada[2]

  texto("downloadStatus", fichero)
  porcentaje("downloadProgress", 0)
  porcentaje("mainProgress", math.floor(100 * (i - 1) / #lista))

  operacion = descargar(base .. fichero:gsub("^/", ""), fichero, ESPERA_FICHERO,
    function(_, recibida, err)
      if not err and recibida ~= huella then
        err = "huella distinta (" .. tostring(recibida) .. " en vez de " .. huella .. ")"
      end
      if err then
        if intentos >= REINTENTOS_DESCARGA then
          return fallo("no puedo descargar " .. fichero .. ": " .. tostring(err))
        end
        evento = scheduleEvent(function()
          bajarFicheros(base, lista, i, intentos + 1, alTerminar)
        end, 500)
        return
      end
      bajarFicheros(base, lista, i + 1, 0, alTerminar)
    end,
    function(progreso)
      porcentaje("downloadProgress", progreso)
    end)
end

local function aplicar(datos)
  if not ventana then return end
  if type(datos) ~= "table" or type(datos.files) ~= "table" or type(datos.url) ~= "string"
      or datos.url:len() < 8 then
    return fallo("la lista de ficheros no es válida")
  end
  local version = tostring(datos.version or "")

  local pendientes, nombres = {}, {}
  for fichero, huella in pairs(datos.files) do
    if type(fichero) == "string" and type(huella) == "string" and fichero:sub(1, 1) == "/"
        and not fichero:find("%.%.") and g_resources.fileChecksum(fichero) ~= huella then
      table.insert(pendientes, { fichero, huella })
      table.insert(nombres, fichero)
    end
  end
  table.sort(pendientes, function(a, b) return a[1] < b[1] end)

  if #pendientes == 0 then
    log("cliente al día (" .. version .. ")")
    return terminar()
  end

  -- Ya lo intentamos con esta versión y no cuajó: no entrar en bucle de reinicios.
  if version ~= "" and leerMarca() == version then
    return fallo(#pendientes .. " ficheros siguen sin actualizar tras instalar la versión " .. version)
  end

  log(#pendientes .. " ficheros nuevos o cambiados (versión " .. version .. ")")
  texto("status", "Actualizando " .. #pendientes .. " ficheros...")
  if ventana.downloadStatus then ventana.downloadStatus:show() end
  if ventana.downloadProgress then ventana.downloadProgress:show() end

  local base = datos.url
  if base:sub(-1) ~= "/" then base = base .. "/" end

  bajarFicheros(base, pendientes, 1, 0, function()
    texto("status", "Instalando la actualización...")
    porcentaje("mainProgress", 100)
    evento = scheduleEvent(function()
      escribirMarca(version)
      g_resources.updateFiles(nombres)
      log("actualización instalada, reiniciando")
      -- Reiniciar siempre: init.lua y las librerías ya están cargados.
      g_app.restart()
    end, 100)
  end)
end

function Updater.init(funcionCargar)
  cargarModulos = funcionCargar
  Updater.check()
end

function Updater.check()
  if ventana then return end
  local ok, w = pcall(g_ui.displayUI, "updater")
  if not ok or not w then
    return fallo("no puedo abrir la ventana del actualizador")
  end
  ventana = w
  ventana:setText("Nocthold")
  texto("status", "Buscando actualizaciones...")
  if ventana.changeUrlButton then ventana.changeUrlButton:hide() end
  ventana:show()
  ventana:raise()
  ventana:focus()

  -- Por si la petición nunca contesta.
  evento = scheduleEvent(function()
    fallo("no contesta " .. tostring(Services.updater))
  end, (ESPERA_LISTA + 2) * 1000)

  local okPedir, err = pcall(function()
    operacion = pedir(Services.updater, ESPERA_LISTA, function(datos, error)
      removeEvent(evento)
      evento = nil
      if error then
        return fallo("no puedo leer la lista: " .. tostring(error))
      end
      aplicar(datos)
    end)
  end)
  if not okPedir then
    fallo("no puedo pedir la lista: " .. tostring(err))
  end
end

-- Botón "Cancelar" de la ventana: arrancar sin actualizar.
function Updater.abort()
  log("cancelado por el jugador")
  terminar()
end

function Updater.changeUrl()
end

function Updater.terminate()
  cargarModulos = nil
  terminar()
end
