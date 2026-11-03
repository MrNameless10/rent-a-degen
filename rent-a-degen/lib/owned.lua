local core = require("lib.core")
local text = core.text
local counter = core.load("lib/counter.lua")
local fx, net = core.fx, core.net
local HEAD = {"BADGE CONTROLLED BY", "SPONSORED BY", "A MESSAGE FROM"}
local scr = {}
local ctx = core.ctx
local buyer, oid, span = ctx.buyer, ctx.oid, ctx.d // 1000
local ends, nextSec, nextBeat = 0, 0, 0
local bar, left, over

local function owed(now)
  local rest = (ends - now) // 1000
  return rest > 0 and math.max(1, ctx.p * rest // span) or 0
end

local function finish(why, debt)
  over = true
  counter.owe(oid, buyer, ctx.bname, debt)
  net.send(buyer, {t = "E", o = oid, w = why})
  core.go(ctx.back)
end

local function early()
  ui.confirm("End " .. ctx.bname .. "'s rental now?\nYou refund " .. owed(sys.millis()) .. " !LAMPs.", function(yes)
    if not yes or over then return end
    local amount = owed(sys.millis())
    finish("early", amount)
    lamps.transfer(buyer, amount, "rent-a-degen refund", function(ok)
      if not ok then return end
      core.stats.e = core.stats.e - amount
      core.save()
      counter.owe(oid, buyer, ctx.bname, 0)
    end)
  end)
end

scr.on = setmetatable({
  o = function(from, m)
    local id = core.int(m.o, 1, 999999)
    if id and id ~= oid then net.send(from, {t = "r", o = id, w = "busy"}) end
  end,
  c = function(from, m)
    local c = core.int(m.c, 1, #fx.COLORS)
    if from == buyer and m.o == oid and c then fx.color(c) end
  end,
  b = function(from, m)
    if from == buyer and m.o == oid then fx.f = 300 end
  end,
}, {__index = counter.on})

function scr.enter()
  core.ctx = nil
  ends = sys.millis() + span * 1000
  counter.m, counter.b, counter.n = ctx.m, true, #core.cfg.o
  fx.start(ctx.f, ctx.c)
  net.send(buyer, {t = "g", o = oid, d = span * 1000})
  counter.owe(oid, buyer, ctx.bname, ctx.p)
  text(0, 4, HEAD[ctx.x] or HEAD[1], 14, "green", ui.W, "center")
  core.big(0, 34, ctx.bname, ui.W)
  text(10, 84, ctx.x == 3 and ctx.text or ctx.n, 20, nil, 300, "center")
  ui.hint("CANCEL end early + refund")
  bar = ui.bar(10, 158, 300, 8, 100)
  left = text(0, 172, core.dur(span) .. " left", 12, "dim", ui.W, "center")
end

function scr.leave()
  if not over then
    counter.owe(oid, buyer, ctx.bname, owed(sys.millis()))
    net.send(buyer, {t = "E", o = oid, w = "quit"})
    net.send("*", {t = "x"})
  end
  fx.start(0)
end

function scr.key(k)
  if k == "back" then early() end
  return true
end

function scr.tick(now)
  if over then return end
  if now >= ends then return finish("done", 0) end
  counter.tick(now)
  if now >= nextSec then
    nextSec = now + 1000
    local rest = (ends - now + 999) // 1000
    bar:set(rest * 100 // span)
    left:text(core.dur(rest) .. " left")
  end
  if now >= nextBeat then
    nextBeat = now + 3000
    net.send(buyer, {t = "z", o = oid, m = ends - now})
  end
end

return scr
