local core = require("lib.core")
local text = core.text
local fx, net = core.fx, core.net
local scr = {}
local OVER = {
  done = "Your time is up.",
  early = "Ended early. The rest is refunded.",
  quit = "They left the app. They'll be asked to refund you.",
}
local ctx = core.ctx
local seller, sname, oid, pixel = ctx.seller, ctx.sname, ctx.oid, ctx.kind == 2
local col, sent, lastZ, ends = ctx.c, ctx.c, 0, 0
local nextCol, nextFlash, nextDraw = 0, 0, 0
local status, bar, left, cl, over

local function done(why)
  over = true
  fx.start(0)
  core.clear()
  text(0, 40, "RENTAL OVER", 14, "green", ui.W, "center")
  core.big(0, 64, sname, ui.W)
  text(10, 116, OVER[why] or "Lost contact. If they quit, they'll be asked to refund you.", 14, nil, 300, "center")
  ui.hint("SELECT more degens")
end

local function mine(f)
  return function(from, m)
    if from == seller and m.o == oid and not over then f(m) end
  end
end

scr.on = {
  z = mine(function(m)
    local rest = core.int(m.m, 0, 86400000)
    if rest then lastZ, ends = sys.millis(), sys.millis() + rest end
  end),
  E = mine(function(m) done(m.w) end),
}

function scr.enter()
  core.ctx = nil
  local now = sys.millis()
  lastZ, ends = now, now + ctx.ms
  fx.start(pixel and 1 or ctx.f, col)
  core.art(18, 28, pixel and "#" .. ctx.k or "YOURS")
  text(120, 6, pixel and "YOUR PIXEL ON" or "YOU OWN", 12, "green")
  core.big(120, 22, sname)
  text(120, 60, ctx.n, 14, "dim")
  text(120, 84, "COLOUR", 12, "dim")
  cl = text(176, 82, fx.CNAMES[col], 14, fx.COLORS[col])
  text(120, 106, "TIME", 12, "dim")
  bar = ui.bar(170, 109, 76, 8, 100)
  left = text(250, 106, "", 12, nil, 62, "right")
  text(18, 132, "LEFT/RIGHT", 12, "dim")
  text(18, 148, pixel and "colour" or "SELECT flash", 12, "dim")
  status = text(18, 178, "Live on " .. sname .. "'s badge", 14, "green", 290)
  ui.hint(pixel and "LEFT/RIGHT colour   CANCEL back" or "LEFT/RIGHT colour   SELECT flash")
end

function scr.leave() fx.start(0) end

function scr.key(k, rep)
  if over then
    if k == "select" or k == "back" then core.go("lib/buy.lua") end
  elseif k == "left" or k == "right" then
    col = fx.color(col + (k == "left" and -1 or 1))
    cl:text(fx.CNAMES[col])
    cl:color(fx.COLORS[col])
  elseif k == "select" and not pixel and not rep then
    local now = sys.millis()
    if now >= nextFlash then
      nextFlash = now + 1000
      fx.f = 300
      net.send(seller, {t = "b", o = oid})
    end
  elseif k == "back" then
    core.ctx = pixel and {seller = seller, sname = sname} or nil
    core.go(pixel and "lib/pixbuy.lua" or "lib/buy.lua")
  end
  return true
end

function scr.tick(now)
  if over then return end
  if col ~= sent and now >= nextCol then
    sent, nextCol = col, now + 400
    net.send(seller, {t = "c", o = oid, c = col})
  end
  if now < nextDraw then return end
  nextDraw = now + 1000
  local rest = math.max(0, ends - now) // 1000
  bar:set(rest * 100 // ctx.d)
  left:text(core.dur(rest))
  if not pixel and now - lastZ > 10000 then
    status:text("Lost contact with " .. sname)
    status:color("orange")
  end
  if rest == 0 and now - math.max(lastZ, ends) > 15000 then done("lost") end
end

return scr
