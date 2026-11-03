local core = require("lib.core")
local net, stats = core.net, core.stats
local c = {m = 1, n = 0, lo = 0, b = false, on = {}}
local BASE, PAY, CHECK = 1, 2, 3
local st, who, oid, price, base, paid, failed, asking
local deadline, nextAt, polls, nextHello = 0, 0, 0, 0

function c.hello(to)
  net.send(to, {t = "h", m = c.m, n = c.n, lo = c.lo, b = c.b and 1 or 0})
end

function c.sold(name, amount)
  stats.e, stats.r = stats.e + amount, stats.r + 1
  table.insert(stats.last, 1, name)
  stats.last[6] = nil
  core.save()
end

function c.owe(o, to, n, a) core.load("lib/owe.lua")(o, to, n, a) end

local function close(why)
  local f = failed
  if why ~= "cancel" then net.send(who, {t = "r", o = oid, w = why}) end
  st, who, oid, paid, failed = nil
  f(why)
end

function c.charge(to, o, amount, ok, ko)
  st, who, oid, price, paid, failed, asking = BASE, to, o, amount, ok, ko, true
  lamps.balance(function(good, bal)
    asking = false
    if st ~= BASE or oid ~= o then return end
    if not good then return close("offline") end
    st, base, deadline, nextAt = PAY, bal, sys.millis() + 60000, 0
  end)
end

function c.drop(why)
  if st then close(why) end
end

function c.tick(now)
  if now >= nextHello and net.idle() then
    nextHello = now + 4000
    c.hello("*")
  end
  if st == PAY then
    if now >= deadline then return close("timeout") end
    if now >= nextAt then
      nextAt = now + 3000
      net.send(who, {t = "$", o = oid, p = price})
    end
  elseif st == CHECK and not asking and now >= nextAt then
    asking, nextAt = true, now + 2000
    local o = oid
    lamps.balance(function(good, bal)
      asking = false
      if st ~= CHECK or oid ~= o then return end
      if good and bal >= base + price then
        local f = paid
        st, who, oid, paid, failed = nil
        return f()
      end
      polls = polls + 1
      if polls >= 8 then close("unpaid") end
    end)
  end
end

c.on["?"] = function(from) c.hello(from) end

c.on.l = function(from)
  if c.menu then c.menu(from) end
end

c.on.P = function(from, m)
  if st == PAY and from == who and m.o == oid then st, polls, nextAt = CHECK, 0, 0 end
end

c.on.n = function(from, m)
  if (st == BASE or st == PAY) and from == who and m.o == oid then close("cancel") end
end

return c
