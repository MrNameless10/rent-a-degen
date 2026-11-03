local core = require("lib.core")
local text = core.text
local counter = core.load("lib/counter.lua")
local fx, net, px = core.fx, core.net, core.cfg.px
local scr = {}
local grid, lease, rows = {0, 0, 0, 0, 0, 0, 0, 0}, {}, {}
local used, waiting, head, status, nextSec = 0, nil, nil, nil, 0

local function say(s, color)
  status:text(s)
  status:color(color or "green")
end

local function state(to)
  local u = {}
  for i = 1, 8 do u[i] = lease[i] and lease[i].c or 0 end
  net.send(to, {t = "X", p = px.p, s = px.s, q = px.q, u = u})
end

local function refresh(now)
  local lo
  for i = 1, 8 do
    local l, p = lease[i], px.p[i]
    if l then
      rows[i]:text(i .. "  " .. l.name .. "  " .. core.dur((l.ends - now + 999) // 1000))
      rows[i]:color(fx.COLORS[l.c])
    else
      rows[i]:text(i .. "  free  " .. p .. " !L/" .. core.dur(px.s))
      rows[i]:color("dim")
      if not lo or p < lo then lo = p end
    end
  end
  head:text(used == 8 and "100% COMMUNITY-OWNED" or "PIXEL LANDLORD  " .. used .. "/8")
  counter.n, counter.lo, counter.b = 8 - used, lo or 0, used == 8
end

local function start(w)
  local now = sys.millis()
  lease[w.k] = {who = w.who, name = w.name, o = w.o, c = w.c, p = w.price, span = w.secs, ends = now + w.secs * 1000}
  grid[w.k], used = fx.COLORS[w.c], used + 1
  counter.sold(w.name, w.price)
  counter.owe(w.o, w.who, w.name, w.price)
  net.send(w.who, {t = "g", o = w.o, d = w.secs * 1000})
  say(w.name .. " rents pixel " .. w.k)
  refresh(now)
end

local function release(i)
  local l = lease[i]
  net.send(l.who, {t = "E", o = l.o, w = "done"})
  counter.owe(l.o, l.who, l.name, 0)
  lease[i], grid[i], used = nil, 0, used - 1
  say("Pixel " .. i .. " is free again", "dim")
end

local function reject(to, o, why) net.send(to, {t = "r", o = o, w = why}) end

scr.on = setmetatable({
  o = function(from, m)
    local id = core.int(m.o, 1, 999999)
    if not id then return end
    if waiting then
      if id ~= waiting.o then reject(from, id, "queue") end
      return
    end
    local k, q, c = core.int(m.k, 1, 8), core.int(m.q, 1, px.q), core.int(m.c, 1, #fx.COLORS)
    local price = k and q and px.p[k] * q
    if not (price and c) or m.p ~= price or price > core.CAP then return reject(from, id, "changed") end
    if lease[k] then return reject(from, id, "taken") end
    if not badge.online() then return reject(from, id, "offline") end
    local w = {who = from, o = id, k = k, c = c, secs = px.s * q, price = price, name = core.clean(core.nameOf(from), 12) or from}
    waiting = w
    say(w.name .. " is paying for pixel " .. k, "yellow")
    counter.charge(from, id, price, function()
      waiting = nil
      start(w)
    end, function(why)
      waiting = nil
      say("Last order: " .. why, "dim")
    end)
  end,
  c = function(from, m)
    local c = core.int(m.c, 1, #fx.COLORS)
    for i = 1, 8 do
      local l = lease[i]
      if c and l and l.who == from and l.o == m.o then l.c, grid[i] = c, fx.COLORS[c] end
    end
    refresh(sys.millis())
  end,
}, {__index = counter.on})

function scr.enter()
  local online = badge.online()
  if not online and wifi.status() == "off" then wifi.on() end
  core.art(18, 28, "PIXELS")
  head = text(120, 6, "", 12, "green")
  core.big(120, 22, core.me())
  for i = 1, 8 do rows[i] = text(120, 50 + i * 14, "", 12, nil, 190) end
  text(18, 132, "BADGE " .. (badge.id() or "?"), 12, "dim")
  text(18, 148, "1-6 top\n7-8 side", 12, "dim")
  status = text(18, 178, "", 14, nil, 290)
  ui.hint("CANCEL close shop")
  say(online and "Pixels for rent" or "Turn Wi-Fi on to get paid", online and "green" or "orange")
  counter.m, counter.menu = 2, state
  fx.start(8, nil, grid)
  refresh(sys.millis())
  counter.hello("*")
end

function scr.leave()
  local now = sys.millis()
  for i = 1, 8 do
    local l = lease[i]
    if l then
      local rest = (l.ends - now) // 1000
      counter.owe(l.o, l.who, l.name, rest > 0 and math.max(1, l.p * rest // l.span) or 0)
      net.send(l.who, {t = "E", o = l.o, w = "quit"})
    end
  end
  counter.drop("closed")
  net.send("*", {t = "x"})
  fx.start(0)
end

function scr.key(k)
  if k ~= "back" then return true end
  if used == 0 then
    core.go(core.home)
    return true
  end
  ui.confirm("Close the shop?\n" .. core.plural(used, "renter") .. " will be offered refunds.", function(yes)
    if yes then core.go(core.home) end
  end)
  return true
end

function scr.tick(now)
  counter.tick(now)
  if now < nextSec then return end
  nextSec = now + 1000
  for i = 1, 8 do
    local l = lease[i]
    if l and now >= l.ends then release(i) end
  end
  refresh(now)
end

return scr
