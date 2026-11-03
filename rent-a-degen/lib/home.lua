local core = require("lib.core")
local text = core.text
local fx, stats, cfg = core.fx, core.stats, core.cfg
local scr = {}
local KEYS = {select = "lib/open.lua", right = "lib/buy.lua", left = "lib/edit.lua"}
local shops, line, nextCount = {}, nil, 0

local function nearby()
  local n = 0
  for _ in pairs(shops) do n = n + 1 end
  return n == 0 and "No degens for sale nearby" or core.plural(n, "degen") .. " for sale nearby"
end

local function meter(y, label, v, top)
  text(120, y, label, 12, "dim")
  ui.bar(170, y + 3, 104, 8, v * 100 // top)
  text(282, y, tostring(v), 12)
end

function scr.enter()
  local owner, top = badge.owner(), math.max(10, stats.r, stats.b)
  core.clear()
  core.art(18, 28, core.plural(#cfg.o, "offer"))
  fx.start(7, 1)
  text(120, 6, owner and "PEOPLE ARE THE PRODUCT" or "CLAIM YOUR BADGE FIRST", 12, owner and "green" or "orange")
  core.big(120, 22, core.me())
  text(120, 62, "earned " .. stats.e .. " !L, spent " .. stats.s .. " !L", 12, "dim")
  meter(84, "SOLD", stats.r, top)
  meter(106, "BOUGHT", stats.b, top)
  text(120, 130, #stats.last > 0 and "last " .. table.concat(stats.last, " ", 1, math.min(3, #stats.last)) or "nobody rented you yet", 12, "dim", 190)
  text(18, 132, "BADGE " .. (badge.id() or "?"), 12, "dim")
  line = text(18, 178, nearby(), 14, "green")
  ui.hint("SELECT sell me   RIGHT rent   LEFT my prices")
  core.net.send("*", {t = "?"})
  if storage.get("owe") then core.load("lib/refund.lua")() end
end

scr.on = {
  h = function(from) shops[from] = sys.millis() end,
  x = function(from) shops[from] = nil end,
}

function scr.leave() fx.start(0) end

function scr.key(k)
  if k == "back" then return false end
  if KEYS[k] then core.go(KEYS[k]) end
  return true
end

function scr.tick(now)
  if now < nextCount then return end
  nextCount = now + 1000
  for id, seen in pairs(shops) do
    if now - seen > 12000 then shops[id] = nil end
  end
  line:text(nearby())
end

return scr
