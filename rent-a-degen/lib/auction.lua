local core = require("lib.core")
local text = core.text
local counter = core.load("lib/counter.lua")
local fx, net, cfg = core.fx, core.net, core.cfg
local au = cfg.au
local offer = cfg.o[au.k] or cfg.o[1]
local scr = {}
local OPEN, SETTLE, OVER = 1, 2, 3
local SNIPE = 10000
local st, ends, rank, handoff, closing = OPEN, 0, {}, false, false
local price, by, bar, left, count, status
local nextSec, nextState = 0, 0

local function need() return rank[1] and rank[1].v + au.i or au.r end

local function say(s, color)
  status:text(s)
  status:color(color or "green")
end

local function state(to)
  local top = rank[1]
  net.send(to, {t = "A", n = offer.n, f = offer.f, c = offer.c, d = au.d, l = au.l, r = au.r, i = au.i,
    h = top and top.v or 0, w = top and top.id or "", b = top and top.name or "",
    e = st == OPEN and math.max(0, ends - sys.millis()) or 0, k = #rank, s = st})
end

local function show(now)
  local top = rank[1]
  local rest = st == OPEN and math.max(0, ends - now) or 0
  price:text((top and top.v or au.r) .. " !L")
  by:text(top and "by " .. top.name or "reserve, no bids yet")
  count:text(core.plural(#rank, "bid"))
  bar:set(rest // (au.l * 10))
  left:text(core.dur((rest + 999) // 1000))
  counter.n, counter.lo, counter.b = #rank, need(), st ~= OPEN
end

local function open()
  st, rank, ends, nextState = OPEN, {}, sys.millis() + au.l * 1000, 0
  fx.start(7, 1)
  say("Bidding is open")
end

local function settle()
  local top = rank[1]
  nextState = 0
  if not top then
    st = OVER
    return say("No winner. SELECT to start again", "dim")
  end
  st = SETTLE
  say(top.name .. " won, paying " .. top.v .. " !L...", "yellow")
  counter.charge(top.id, top.o, top.v, function()
    counter.sold(top.name, top.v)
    core.ctx = {buyer = top.id, bname = top.name, oid = top.o, f = offer.f, c = offer.c, n = offer.n,
      x = offer.x == 3 and 1 or offer.x, d = au.d * 1000, p = top.v, m = 3, back = "lib/auction.lua"}
    handoff = true
    core.go("lib/owned.lua")
  end, function()
    if closing then return end
    table.remove(rank, 1)
    settle()
  end)
end

scr.on = setmetatable({
  B = function(from, m)
    local o, v = core.int(m.o, 1, 999999), core.int(m.v, 1, core.CAP)
    if not (o and v) then return end
    if st ~= OPEN then return net.send(from, {t = "r", o = o, w = "closed"}) end
    if v < need() then return net.send(from, {t = "r", o = o, w = "low"}) end
    for i = #rank, 1, -1 do
      if rank[i].id == from then table.remove(rank, i) end
    end
    table.insert(rank, 1, {id = from, o = o, v = v, name = core.clean(core.nameOf(from), 16) or from})
    local now = sys.millis()
    if ends - now < SNIPE then ends = now + SNIPE end
    nextState = 0
    say(rank[1].name .. " bids " .. v .. " !L")
    show(now)
  end,
}, {__index = counter.on})

function scr.enter()
  if not badge.online() and wifi.status() == "off" then wifi.on() end
  core.clear()
  core.art(18, 28, "AUCTION")
  text(120, 6, "HOSTILE TAKEOVER", 12, "green")
  price = text(120, 22, "", 32)
  by = text(120, 60, "", 14, "dim", 190)
  text(120, 82, "for " .. offer.n .. ", " .. core.dur(au.d), 12, "dim", 190)
  text(120, 106, "TIME", 12, "dim")
  bar = ui.bar(170, 109, 76, 8, 100)
  left = text(250, 106, "", 12, nil, 62, "right")
  text(18, 132, "BADGE " .. (badge.id() or "?"), 12, "dim")
  count = text(18, 148, "", 12, "dim")
  status = text(18, 178, "", 14, nil, 290)
  ui.hint("SELECT restart   CANCEL close")
  counter.m, counter.menu = 3, state
  open()
  show(sys.millis())
end

function scr.leave()
  if handoff then return end
  closing = true
  counter.drop("closed")
  net.send("*", {t = "x"})
  fx.start(0)
end

function scr.key(k)
  if k == "back" then
    core.go(core.home)
  elseif k == "select" and st == OVER then
    open()
  end
  return true
end

function scr.tick(now)
  counter.tick(now)
  if st == OPEN and now >= ends then settle() end
  if now >= nextState and net.idle() then
    nextState = now + 2000
    state("*")
  end
  if now >= nextSec then
    nextSec = now + 1000
    show(now)
  end
end

return scr
