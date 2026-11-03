local core = require("lib.core")
local text = core.text
local counter = core.load("lib/counter.lua")
local fx, net, cfg = core.fx, core.net, core.cfg
local scr = {}
local status, order, handoff, nextAsk = nil, nil, false, 0

local function say(s, color)
  status:text(s)
  status:color(color or "green")
end

local function idle(note)
  order, counter.b = nil, false
  fx.start(7, 2)
  if note then say(note .. ". Waiting...", "dim") else say("Waiting for degens...") end
end

local function reject(to, o, why) net.send(to, {t = "r", o = o, w = why}) end

local function sold()
  local o = order
  counter.sold(o.name, o.price)
  core.ctx = {buyer = o.buyer, bname = o.name, oid = o.oid, f = o.offer.f, c = o.offer.c, n = o.offer.n,
    x = o.offer.x, d = o.secs * 1000, p = o.price, text = o.text, m = 1, back = "lib/sell.lua"}
  handoff = true
  core.go("lib/owned.lua")
end

local function charge()
  local o = order
  o.ask = false
  say(o.name .. " is paying " .. o.price .. " !L...", "yellow")
  counter.charge(o.buyer, o.oid, o.price, sold, function(why)
    idle(why == "cancel" and o.name .. " cancelled" or "Last order: " .. why)
  end)
end

local function offers(to)
  for i, o in ipairs(cfg.o) do
    net.send(to, {t = "i", k = i, n = o.n, f = o.f, c = o.c, s = o.s, p = o.p, q = o.q, x = o.x})
  end
  net.send(to, {t = "e", c = #cfg.o})
end

local function lowest()
  local lo
  for _, o in ipairs(cfg.o) do
    if not lo or o.p < lo then lo = o.p end
  end
  return lo or 0
end

scr.on = setmetatable({
  o = function(from, m)
    local id = core.int(m.o, 1, 999999)
    if not id then return end
    if order then
      if id ~= order.oid then reject(from, id, "busy") end
      return
    end
    local offer = cfg.o[m.k]
    local q = offer and core.int(m.q, 1, offer.q)
    local price = q and offer.p * q
    if not q or m.p ~= price or price > core.CAP then return reject(from, id, "changed") end
    if not badge.online() then return reject(from, id, "offline") end
    local name = core.nameOf(from)
    order = {buyer = from, oid = id, offer = offer, secs = offer.s * q, price = price, name = name,
      text = offer.x == 3 and core.clean(m.m) or nil}
    counter.b = true
    if not (order.text and cfg.ap) then return charge() end
    local mine = order
    mine.ask, nextAsk = true, 0
    say(name .. " wants " .. offer.n, "yellow")
    ui.confirm(name .. " wants to show:\n\"" .. mine.text .. "\"\nfor " .. price .. " !LAMPs. OK?", function(yes)
      if order ~= mine then return end
      if yes then return charge() end
      reject(from, id, "declined")
      idle("Declined " .. name)
    end)
  end,
  n = function(from, m)
    if order and order.ask and from == order.buyer and m.o == order.oid then
      return idle(order.name .. " cancelled")
    end
    counter.on.n(from, m)
  end,
}, {__index = counter.on})

function scr.enter()
  if not badge.online() and wifi.status() == "off" then wifi.on() end
  local lo, online = lowest(), badge.online()
  counter.m, counter.n, counter.lo, counter.menu = 1, #cfg.o, lo, offers
  core.art(18, 28, lo .. " !L")
  text(120, 6, online and "FOR SALE" or "OFFLINE: !LAMPS NEED WI-FI", 12, online and "green" or "orange")
  core.big(120, 22, core.me())
  text(120, 60, core.plural(#cfg.o, "offer") .. ", from " .. lo .. " !L", 14, "dim")
  for i, o in ipairs(cfg.o) do
    text(120, 64 + i * 16, o.n, 12)
    text(214, 64 + i * 16, o.p .. " !L/" .. core.dur(o.s), 12, "dim", 92, "right")
  end
  text(18, 132, "BADGE " .. (badge.id() or "?"), 12, "dim")
  text(18, 148, "sold " .. core.stats.r .. "x", 12, "dim")
  ui.hint("CANCEL close shop")
  status = text(18, 178, "", 14, "green", 290)
  idle()
  counter.hello("*")
end

function scr.leave()
  if handoff then return end
  if order and order.ask then reject(order.buyer, order.oid, "closed") end
  counter.drop("closed")
  net.send("*", {t = "x"})
  fx.start(0)
end

function scr.key(k)
  if k == "back" then core.go(core.home) end
  return true
end

function scr.tick(now)
  counter.tick(now)
  if order and order.ask and now >= nextAsk then
    nextAsk = now + 3000
    net.send(order.buyer, {t = "w", o = order.oid})
  end
end

return scr
