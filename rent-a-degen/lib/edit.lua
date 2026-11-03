local core = require("lib.core")
local form = core.load("lib/form.lua")
local fx, cfg = core.fx, core.cfg
local scr = {}
local keys, top

local function num(label, t, k, min, max, step, unit)
  return {label = label, t = t, k = k, min = min, max = max, step = step, unit = unit}
end

local function offer(i)
  local o = cfg.o[i]
  local function preview() fx.start(o.f, o.c) end
  keys = form("OFFER " .. i, {
    {label = "Name", t = o, k = "n", text = 14},
    {label = "Effect", t = o, k = "f", enum = fx.NAMES},
    {label = "Colour", t = o, k = "c", enum = fx.CNAMES},
    num("Block", o, "s", 5, 300, 5, "s"),
    num("Price per block", o, "p", 1, core.CAP, 1, " !L"),
    num("Max blocks", o, "q", 1, 60, 1, ""),
    {label = "Screen", t = o, k = "x", enum = core.TEXT},
    {label = "Delete this offer", action = function()
      ui.confirm("Delete " .. o.n .. "?", function(yes)
        if not yes then return end
        table.remove(cfg.o, i)
        cfg.au.k = math.max(1, math.min(cfg.au.k, #cfg.o))
        core.save()
        top()
      end)
    end},
  }, preview)
  preview()
end

local function pixels()
  local px, f = cfg.px, {}
  for i = 1, 8 do f[i] = num("Pixel " .. i .. (i > 6 and " (side)" or " (top)"), px.p, i, 1, core.CAP, 1, " !L") end
  f[9] = num("Block", px, "s", 5, 300, 5, "s")
  f[10] = num("Max blocks", px, "q", 1, 60, 1, "")
  keys = form("PIXEL PRICES", f)
end

local function auction()
  local au, names = cfg.au, {}
  for i, o in ipairs(cfg.o) do names[i] = o.n end
  if #names == 0 then return ui.toast("Add an offer first") end
  au.k = math.min(au.k, #names)
  keys = form("AUCTION", {
    {label = "Offer", t = au, k = "k", enum = names},
    num("Reserve", au, "r", 1, core.CAP, 1, " !L"),
    num("Min raise", au, "i", 1, 50, 1, " !L"),
    num("Slot", au, "d", 10, 600, 10, "s"),
    num("Bidding time", au, "l", 20, 300, 10, "s"),
  })
end

function top()
  local rows, acts, n = {}, {}, #cfg.o
  local function add(row, act) rows[#rows + 1], acts[#rows + 1] = row, act end
  keys = nil
  fx.start(0)
  core.title("MY PRICES")
  for i, o in ipairs(cfg.o) do
    add({title = o.n, sub = fx.NAMES[o.f]:lower() .. ", " .. fx.CNAMES[o.c] .. ", up to " .. core.dur(o.s * o.q) .. ", " .. core.TEXT[o.x],
      right = o.p .. " !L/" .. core.dur(o.s)}, function() offer(i) end)
  end
  add({title = "Pixel prices", right = "8 LEDs"}, pixels)
  add({title = "Auction", right = cfg.o[cfg.au.k] and cfg.o[cfg.au.k].n}, auction)
  add({title = "Approve buyers' texts", right = cfg.ap and "ON" or "OFF"}, function()
    cfg.ap = not cfg.ap
    core.save()
    top()
  end)
  add({title = "Reset everything"}, function()
    ui.confirm("Replace all your prices with the examples?", function(yes)
      if not yes then return end
      local d = core.load("lib/defaults.lua")()
      cfg.o, cfg.px, cfg.au, cfg.ap = d.o, d.px, d.au, d.ap
      core.save()
      top()
    end)
  end)
  if n < core.MAX then
    add({title = "+ Add an offer"}, function()
      cfg.o[n + 1] = {n = "NEW OFFER", f = 1, c = 1, s = 10, p = 2, q = 30, x = 1}
      core.save()
      offer(n + 1)
    end)
  end
  ui.list(0, 28, ui.W, ui.H - 44, rows, {on_select = function(i) acts[i]() end})
  ui.hint("SELECT edit   CANCEL back")
end

function scr.enter() top() end

function scr.leave()
  core.save()
  fx.start(0)
end

function scr.key(k, rep)
  if k ~= "back" then
    if keys then keys(k, rep) end
  elseif keys then
    core.save()
    top()
  else
    core.go(core.home)
  end
  return true
end

return scr
