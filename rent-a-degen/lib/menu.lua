local core = require("lib.core")
local fx, net = core.fx, core.net
local scr = {}
local ctx = core.ctx
local seller, sname = ctx.seller, ctx.sname
local menu, list, picker, showMenu = {}, nil, nil, nil
local tries, nextSend = 0, 0

local function leave(why)
  core.ctx = {toast = why}
  core.go("lib/buy.lua")
end

local function order(o, q, text)
  core.ctx = {seller = seller, sname = sname, kind = 1, k = o.k, q = q, p = o.p * q, n = o.n, d = o.s * q,
    f = o.f, c = o.c, x = o.x, text = text}
  core.go("lib/rent.lua")
end

local function choose(o)
  list = nil
  picker = core.load("lib/pick.lua")(o.n .. " ON " .. sname:upper(), o.s, o.p, o.q, false, function(q)
    picker = nil
    if not q then return showMenu() end
    if o.x ~= 3 then return order(o, q) end
    ui.input("Text for " .. sname .. "'s screen", 40, function(t)
      t = core.clean(t)
      if t then order(o, q, t) else showMenu() end
    end)
  end)
end

function showMenu()
  local rows = {}
  for i, o in ipairs(menu) do
    rows[i] = {title = o.n, right = o.p .. " !L/" .. core.dur(o.s),
      sub = fx.NAMES[o.f]:lower() .. ", " .. fx.CNAMES[o.c] .. ", up to " .. core.dur(o.s * o.q) .. (o.x == 3 and ", your text" or "")}
  end
  core.title(sname:upper() .. "'S MENU")
  list = ui.list(0, 28, ui.W, ui.H - 44, rows, {on_select = function(i) choose(menu[i]) end})
  ui.hint("SELECT choose   CANCEL back")
end

scr.on = {
  i = function(from, m)
    if from ~= seller or list or picker then return end
    local k = core.int(m.k, 1, core.MAX)
    if k and core.int(m.f, 1, #fx.NAMES) and core.int(m.c, 1, #fx.COLORS) and core.int(m.s, 1, 3600)
        and core.int(m.p, 1, core.CAP) and core.int(m.q, 1, 999) and core.int(m.x, 1, 3) then
      m.n = core.clean(m.n, 14) or "?"
      menu[k] = m
    end
  end,
  e = function(from, m)
    local c = core.int(m.c, 1, core.MAX)
    if from ~= seller or list or picker or not c then return end
    for i = 1, c do
      if not menu[i] then return end
    end
    for i = c + 1, core.MAX do menu[i] = nil end
    showMenu()
  end,
  x = function(from)
    if from == seller then leave(sname .. " closed the shop") end
  end,
}

function scr.enter()
  local toast = ctx.toast
  core.ctx = nil
  core.title(sname:upper() .. "'S MENU")
  core.text(10, 40, "Loading the menu...", 14)
  ui.hint("CANCEL back")
  if toast then ui.toast(toast) end
end

function scr.key(k, rep)
  if picker then
    picker(k, rep)
  elseif k == "back" then
    core.go("lib/buy.lua")
  end
  return true
end

function scr.tick(now)
  if list or picker or now < nextSend then return end
  if tries >= 4 then return leave("No answer from " .. sname) end
  tries, nextSend = tries + 1, now + 3000
  net.send(seller, {t = "l"})
end

return scr
