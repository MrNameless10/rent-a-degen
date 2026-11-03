local core = require("lib.core")
local fx, net = core.fx, core.net
local scr = {}
local ctx = core.ctx
local seller, sname = ctx.seller, ctx.sname
local grid = {0, 0, 0, 0, 0, 0, 0, 0}
local px, list, picker, draw
local tries, nextAsk = 0, 0

local function rows()
  local r = {}
  for i = 1, 8 do
    local u = px.u[i]
    r[i] = {title = "PIXEL " .. i, sub = u > 0 and "taken, " .. fx.CNAMES[u] or "free", right = px.p[i] .. " !L/" .. core.dur(px.s)}
  end
  return r
end

local function leave(why)
  core.ctx = {toast = why}
  core.go("lib/buy.lua")
end

local function pick(i)
  if not px then return end
  if px.u[i] > 0 then return ui.toast("Pixel " .. i .. " is taken") end
  list = nil
  picker = core.load("lib/pick.lua")("PIXEL " .. i .. " ON " .. sname:upper(), px.s, px.p[i], px.q, true, function(q, c)
    picker = nil
    if not q then return draw() end
    core.ctx = {seller = seller, sname = sname, kind = 2, k = i, q = q, c = c, p = px.p[i] * q, n = "PIXEL " .. i, d = px.s * q}
    core.go("lib/rent.lua")
  end)
end

function draw()
  core.title(sname:upper() .. "'S PIXELS")
  core.art(8, 28, "")
  list = ui.list(100, 28, ui.W - 100, ui.H - 44, px and rows() or {"Loading..."}, {on_select = pick})
  ui.hint("SELECT rent   CANCEL back")
end

scr.on = {
  X = function(from, m)
    if from ~= seller or type(m.p) ~= "table" or type(m.u) ~= "table" then return end
    if not (core.int(m.s, 1, 3600) and core.int(m.q, 1, 999)) then return end
    for i = 1, 8 do
      if not (core.int(m.p[i], 1, core.CAP) and core.int(m.u[i], 0, #fx.COLORS)) then return end
    end
    px, tries = m, 0
    for i = 1, 8 do grid[i] = m.u[i] > 0 and fx.COLORS[m.u[i]] or 0 end
    if list then
      local sel = list:selected()
      list:items(rows())
      if sel then list:select(sel) end
    end
  end,
  x = function(from)
    if from == seller then leave(sname .. " closed the shop") end
  end,
}

function scr.enter()
  local toast = ctx.toast
  core.ctx = nil
  fx.start(8, nil, grid)
  draw()
  if toast then ui.toast(toast) end
end

function scr.leave() fx.start(0) end

function scr.key(k, rep)
  if picker then
    picker(k, rep)
  elseif k == "back" then
    core.go("lib/buy.lua")
  end
  return true
end

function scr.tick(now)
  if picker or now < nextAsk then return end
  if tries >= 4 then return leave("No answer from " .. sname) end
  tries, nextAsk = tries + 1, now + 3000
  net.send(seller, {t = "l"})
end

return scr
