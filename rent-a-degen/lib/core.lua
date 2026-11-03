local core = {fx = require("lib.fx"), net = require("lib.net"), home = "lib/home.lua", MAX = 6, CAP = 500}

core.TEXT = {"effect name", "sponsored by", "buyer's text"}

function core.load(path)
  local chunk, err = fs.load(path)
  if not chunk then error(err) end
  return chunk()
end

core.cfg = storage.get("v1") or core.load("lib/defaults.lua")()
core.stats = storage.get("st") or {e = 0, r = 0, s = 0, b = 0, last = {}}

function core.save()
  storage.set("v1", core.cfg)
  storage.set("st", core.stats)
end

function core.int(v, lo, hi)
  if math.type(v) == "integer" and v >= lo and v <= hi then return v end
end

function core.clean(s, n)
  if type(s) ~= "string" then return nil end
  s = s:sub(1, n or 48):gsub("%c", " ")
  if not utf8.len(s) then s = s:gsub("[\128-\255]", "?") end
  return s ~= "" and s or nil
end

function core.dur(s)
  if s < 60 then return s .. "s" end
  local r = s % 60
  return s // 60 .. "m" .. (r > 0 and r .. "s" or "")
end

function core.plural(n, word)
  return n .. " " .. word .. (n == 1 and "" or "s")
end

function core.nameOf(id)
  for _, p in ipairs(mesh.nearby()) do
    if p.id == id then return p.name ~= "" and p.name or id end
  end
  return id
end

function core.me() return badge.owner() or "THIS HUMAN" end

function core.clear()
  core.fx.view(nil)
  ui.clear()
end

function core.go(path) core.nextScr = path end

function core.switch()
  local path, old = core.nextScr, core.scr
  core.nextScr = nil
  if old and old.leave then old.leave() end
  old, core.scr = nil, nil
  core.clear()
  core.scr = core.load(path)
  core.scr.enter()
end

function core.text(x, y, s, size, color, w, align)
  return ui.label(x, y, s, {size = size, color = color, w = w, align = align})
end

function core.title(t)
  core.clear()
  return core.text(10, 6, t, 14, "dim")
end

function core.big(x, y, s, w)
  s = s:upper()
  return core.text(x, y, s, #s > (w and 15 or 9) and 20 or 32, nil, w, w and "center")
end

function core.art(x, y, word)
  local dark, leds = 0x1C1C24, {}
  ui.rect(x, y, 84, 98, {color = 0x16141E, radius = 8})
  ui.rect(x + 9, y + 22, 66, 48, {color = 0, radius = 3})
  for i = 1, 6 do leds[i] = ui.rect(x - 3 + i * 12, y + 8, 6, 6, {color = dark}) end
  leds[7] = ui.rect(x + 78, y + 30, 4, 8, {color = dark})
  leds[8] = ui.rect(x + 78, y + 50, 4, 8, {color = dark})
  for i = 0, 2 do ui.rect(x + 16 + i * 22, y + 80, 8, 8, {color = 0x2A2836, radius = 4}) end
  core.fx.view(leds)
  return core.text(x + 9, y + 38, word, 12, "green", 66, "center")
end

return core
