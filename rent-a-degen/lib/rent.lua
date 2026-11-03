local core = require("lib.core")
local text = core.text
local net, stats = core.net, core.stats
local scr = {}
local ORDER, PAYING, PAID, GONE = 1, 2, 3, 4
local BACK = {"lib/menu.lua", "lib/pixbuy.lua", "lib/bid.lua"}
local REASON = {
  busy = "is busy with someone else", changed = "changed their prices", declined = "declined your text",
  offline = "is offline (no Wi-Fi)", timeout = "timed out waiting", unpaid = "didn't see your payment",
  closed = "closed the shop", taken = "rented that pixel to someone else",
}
local ctx = core.ctx
local seller, sname = ctx.seller, ctx.sname
local st, oid = ORDER, ctx.oid or math.random(1, 999999)
local order = not ctx.wait and {t = "o", o = oid, k = ctx.k, q = ctx.q, p = ctx.p, c = ctx.kind == 2 and ctx.c or nil, m = ctx.text}
local tries, nextSend, deadline = 0, 0, 0
local status

local function say(s, color)
  status:text(s)
  status:color(color or "text")
end

local function back(why)
  st = GONE
  core.ctx = {seller = seller, sname = sname, toast = why}
  core.go(BACK[ctx.kind])
end

local function send(msg, max, every)
  if tries >= max then return false end
  tries, nextSend = tries + 1, sys.millis() + every
  net.send(seller, msg)
  return true
end

local function pay()
  st = PAYING
  say("Confirm the payment on your badge")
  lamps.transfer(seller, ctx.p, "rent-a-degen #" .. oid .. " " .. ctx.n, function(ok, res)
    if st ~= PAYING then return end
    if not ok then
      net.send(seller, {t = "n", o = oid})
      return back(res == "denied" and "Payment cancelled" or "Payment failed: " .. tostring(res))
    end
    stats.s, stats.b = stats.s + ctx.p, stats.b + 1
    core.save()
    st, tries, nextSend = PAID, 0, 0
    say("Paid. Waiting for " .. sname .. "...", "green")
  end)
end

local function live(ms)
  if st ~= PAID or not ms then return end
  st = GONE
  ctx.oid, ctx.ms = oid, ms
  core.ctx = ctx
  core.go("lib/control.lua")
end

local function mine(f)
  return function(from, m)
    if from == seller and m.o == oid then f(m) end
  end
end

scr.on = {
  r = mine(function(m)
    if m.w == "queue" and st == ORDER then
      tries, nextSend = 0, sys.millis() + 800 + math.random(0, 1600)
      return say("In line, " .. sname .. " is busy...", "yellow")
    end
    if st == ORDER or st == PAID then back(sname .. " " .. (REASON[m.w] or "said no")) end
  end),
  w = mine(function()
    if st ~= ORDER then return end
    tries = 0
    say("Waiting for " .. sname .. " to approve your text...", "yellow")
  end),
  ["$"] = mine(function(m)
    if st == ORDER and m.p == ctx.p then pay() end
  end),
  g = mine(function(m) live(core.int(m.d, 1, 86400000)) end),
  z = mine(function(m) live(core.int(m.m, 0, 86400000)) end),
}

function scr.enter()
  core.ctx = nil
  deadline = sys.millis() + 60000
  text(0, 4, ctx.wait and "AUCTION WON" or "RENT REQUEST", 14, "green", ui.W, "center")
  text(0, 52, core.me(), 14, nil, 160, "center")
  text(150, 52, "vs", 14, "dim", 20, "center")
  text(160, 52, sname, 14, nil, 160, "center")
  text(0, 74, ctx.p .. " !LAMPs", 12, "dim", 160, "center")
  text(160, 74, ctx.n .. " " .. core.dur(ctx.d), 12, "dim", 160, "center")
  status = text(0, 120, ctx.wait and "Waiting for the payment request..." or "Waiting for " .. sname .. " to accept...", 14, nil, ui.W, "center")
  ui.hint("CANCEL abort")
end

function scr.leave()
  if st == ORDER and order then net.send(seller, {t = "n", o = oid}) end
end

function scr.key(k)
  if k ~= "back" then return true end
  if st == ORDER then back(nil) elseif st ~= GONE then ui.toast("Payment in progress") end
  return true
end

function scr.tick(now)
  if st == ORDER then
    if order then
      if now >= nextSend and not send(order, 5, 3000) then back("No answer from " .. sname) end
    elseif now >= deadline then
      back("No payment request from " .. sname)
    end
  elseif st == PAID and now >= nextSend and not send({t = "P", o = oid}, 30, 2000) then
    back("Paid, but " .. sname .. " never answered")
  end
end

return scr
