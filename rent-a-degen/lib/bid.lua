local core = require("lib.core")
local text = core.text
local net = core.net
local scr = {}
local ctx = core.ctx
local seller, sname = ctx.seller, ctx.sname
local me, oid = badge.id(), math.random(1, 999999)
local a, mine, pending, placed, seen = nil, 0, 0, 0, 0
local price, by, slot, bar, left, offer, status
local tries, asks, resend, nextAsk, nextSec = 0, 0, 0, 0, 0
local WHY = {low = "Someone bid more first", closed = "Bidding is closed"}

local function need() return a.h > 0 and a.h + a.i or a.r end

local function say(s, color)
  status:text(s)
  status:color(color or "green")
end

local function leave(why)
  core.ctx = {toast = why}
  core.go("lib/buy.lua")
end

local function show(now)
  if not a then return end
  local rest = math.max(0, a.e - (now - seen))
  price:text((a.h > 0 and a.h or a.r) .. " !L")
  by:text(a.h == 0 and "reserve, no bids yet" or a.w == me and "by YOU" or "by " .. a.b)
  slot:text("for " .. a.n .. ", " .. core.dur(a.d))
  bar:set(math.min(100, rest // (a.l * 10)))
  left:text(core.dur((rest + 999) // 1000))
  mine = math.max(mine, need())
  offer:text("< " .. mine .. " !L >")
  if a.s == 1 then
    if a.w == me then say("You're winning")
    elseif placed > 0 then say("Outbid! Raise and SELECT", "orange")
    else say("SELECT to bid " .. mine .. " !L", "text") end
  elseif a.s == 2 then
    say(a.w == me and "You won! Pay when asked" or "Won by " .. a.b, a.w == me and "green" or "dim")
  else
    say("No winner this round", "dim")
  end
end

local function bid()
  if not a or a.s ~= 1 then return ui.toast("Bidding is closed") end
  local v = mine
  ui.confirm("Bid " .. v .. " !LAMPs on " .. a.n .. "?\nYou only pay if you win.", function(yes)
    if not yes then return end
    pending, tries, resend = v, 0, 0
  end)
end

scr.on = {
  A = function(from, m)
    if from ~= seller or type(m.n) ~= "string" or type(m.w) ~= "string" or type(m.b) ~= "string" then return end
    if not (core.int(m.h, 0, core.CAP) and core.int(m.r, 1, core.CAP) and core.int(m.i, 1, core.CAP)
        and core.int(m.d, 1, 86400) and core.int(m.l, 1, 86400) and core.int(m.e, 0, 86400000) and core.int(m.s, 1, 3)) then
      return
    end
    m.n, m.b = core.clean(m.n, 14) or "?", core.clean(m.b, 16) or "?"
    a, seen, asks = m, sys.millis(), 0
    if pending > 0 and a.w == me and a.h >= pending then pending, placed = 0, a.h end
    show(seen)
  end,
  ["$"] = function(from, m)
    if from ~= seller or m.o ~= oid or not a or m.p ~= placed then return end
    core.ctx = {seller = seller, sname = sname, kind = 3, oid = oid, p = placed, n = a.n, d = a.d,
      f = core.int(a.f, 1, #core.fx.NAMES) or 1, c = core.int(a.c, 1, #core.fx.COLORS) or 1, wait = true}
    core.go("lib/rent.lua")
  end,
  r = function(from, m)
    if from ~= seller or m.o ~= oid then return end
    pending = 0
    ui.toast(WHY[m.w] or "Bid refused")
  end,
  h = function(from, m)
    if from ~= seller or m.b ~= 1 then return end
    seen, asks = sys.millis(), 0
    if a and a.s ~= 1 then say("Slot in use, next auction soon", "dim") end
  end,
  x = function(from)
    if from == seller then leave(sname .. " closed the auction") end
  end,
}

function scr.enter()
  local toast = ctx.toast
  core.ctx = nil
  core.title("AUCTION: " .. sname:upper())
  price = text(10, 30, "...", 32)
  by = text(10, 68, "", 14, "dim", 300)
  slot = text(10, 88, "", 12, "dim", 300)
  text(10, 112, "TIME", 12, "dim")
  bar = ui.bar(60, 115, 186, 8, 100)
  left = text(250, 112, "", 12, nil, 62, "right")
  text(10, 140, "YOUR BID", 12, "dim")
  offer = text(90, 136, "", 20, "green")
  status = text(10, 178, "Waiting for the auction...", 14, nil, 300)
  ui.hint("LEFT/RIGHT amount   SELECT bid   CANCEL leave")
  if toast then ui.toast(toast) end
end

function scr.key(k, rep)
  if k == "back" then
    core.go("lib/buy.lua")
  elseif k == "select" then
    bid()
  elseif a and (k == "left" or k == "right") then
    local step = a.i * (rep and 5 or 1)
    mine = math.max(need(), math.min(core.CAP, mine + (k == "left" and -step or step)))
    show(sys.millis())
  end
  return true
end

function scr.tick(now)
  if pending > 0 and now >= resend then
    if tries >= 3 then
      pending = 0
      ui.toast("No answer to your bid")
    else
      tries, resend = tries + 1, now + 2000
      net.send(seller, {t = "B", o = oid, v = pending})
    end
  end
  if now - seen > 5000 and now >= nextAsk then
    if asks >= 4 then return leave("No answer from " .. sname) end
    asks, nextAsk = asks + 1, now + 3000
    net.send(seller, {t = "l"})
  end
  if now >= nextSec then
    nextSec = now + 1000
    show(now)
  end
end

return scr
