local core = require("lib.core")
local net = core.net
local scr = {}
local SCREEN = {"lib/menu.lua", "lib/pixbuy.lua", "lib/bid.lua"}
local MODE = {"rent", "pixels", "auction"}
local shops, ids, dirty, list, nextDraw = {}, {}, true, nil, 0

local function sub(s)
  if s.m == 2 then return s.n .. "/8 pixels free, from " .. s.lo .. " !L" end
  if s.m == 3 then return core.plural(s.n, "bid") .. ", next bid " .. s.lo .. " !L" end
  return core.plural(s.n, "offer") .. ", from " .. s.lo .. " !L"
end

local function draw()
  local rows = {}
  ids = {}
  for id in pairs(shops) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return shops[a].name < shops[b].name end)
  for i, id in ipairs(ids) do
    local s = shops[id]
    rows[i] = {title = s.name, sub = sub(s), right = s.b == 1 and (s.m == 3 and "closed" or "rented") or MODE[s.m]}
  end
  if #rows == 0 then rows[1] = "Searching for degens..." end
  local sel = math.max(1, list:selected() or 1)
  list:items(rows)
  list:select(math.min(sel, #rows))
end

scr.on = {
  h = function(from, m)
    local mode, n, lo = core.int(m.m, 1, 3), core.int(m.n, 0, 99), core.int(m.lo, 0, core.CAP)
    if not (mode and n and lo) then return end
    local s = shops[from]
    if not s then
      s = {name = core.clean(core.nameOf(from), 20) or from}
      shops[from] = s
    end
    local b = m.b == 1 and 1 or 0
    dirty = dirty or s.m ~= mode or s.n ~= n or s.lo ~= lo or s.b ~= b
    s.m, s.n, s.lo, s.b, s.seen = mode, n, lo, b, sys.millis()
  end,
  x = function(from)
    if shops[from] then shops[from], dirty = nil, true end
  end,
}

function scr.enter()
  local ctx = core.ctx
  core.ctx = nil
  if not badge.online() and wifi.status() == "off" then wifi.on() end
  core.fx.start(0)
  core.title("DEGENS FOR SALE")
  list = ui.list(0, 28, ui.W, ui.H - 44, {}, {on_select = function(i)
    local s = shops[ids[i]]
    if not s then return end
    if s.b == 1 and s.m == 1 then return ui.toast(s.name .. " is rented right now") end
    core.ctx = {seller = ids[i], sname = s.name}
    core.go(SCREEN[s.m])
  end})
  ui.hint("SELECT open   CANCEL back")
  net.send("*", {t = "?"})
  if ctx and ctx.toast then ui.toast(ctx.toast) end
end

function scr.key(k)
  if k == "back" then core.go(core.home) end
  return true
end

function scr.tick(now)
  if now < nextDraw then return end
  nextDraw = now + 1000
  for id, s in pairs(shops) do
    if now - s.seen > 12000 then shops[id], dirty = nil, true end
  end
  if dirty then
    dirty = false
    draw()
  end
end

return scr
