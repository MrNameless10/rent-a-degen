local fx = {
  NAMES = {"SOLID", "RUG PULL", "RAINBOW", "WAVE", "STROBE", "POLICE", "BREATHE"},
  COLORS = {0x9945FF, 0x14F195, 0xFF3EA5, 0x00C2FF, 0xFFD000, 0xFF7A00, 0xFF2020, 0xFFFFFF},
  CNAMES = {"purple", "green", "pink", "blue", "yellow", "orange", "red", "white"},
  f = 0,
}
local PERIOD = {1, 140, 2, 90, 60, 200, 2400, 3000}
local kind, col, t, grid, view, shown = 0, 1, 0, nil, nil, {}

local function dim(c, k)
  return (c >> 16) * k // 255 << 16 | (c >> 8 & 255) * k // 255 << 8 | (c & 255) * k // 255
end

local function wave(p, lo)
  local x = t % p
  if x > p // 2 then x = p - x end
  return lo + x * (255 - lo) * 2 // p
end

local function hue(h)
  local s, x = h // 256 % 6, h % 256
  if s == 0 then return 0xFF0000 | x << 8 end
  if s == 1 then return (255 - x) << 16 | 0xFF00 end
  if s == 2 then return 0xFF00 | x end
  if s == 3 then return (255 - x) << 8 | 0xFF end
  if s == 4 then return x << 16 | 0xFF end
  return 0xFF0000 | 255 - x
end

local function shade(i, c, p)
  if fx.f > 0 then return 0xFFFFFF end
  if kind == 1 then return c end
  if kind == 2 or kind == 5 then return t // p % 2 == 0 and c or 0 end
  if kind == 3 then return hue(t // 2 + i * 192) end
  if kind == 4 then return dim(c, 255 >> (i - 1 - t // p) % 8 * 2) end
  if kind == 6 then
    local a = t // p % 2 == 0
    return (i <= 4) == a and (a and 0xFF0000 or 0xFF) or 0
  end
  if kind == 7 then return dim(c, wave(p, 20)) end
  return grid[i] ~= 0 and grid[i] or dim(0x14F195, wave(p, 8))
end

function fx.color(c)
  col = (c - 1) % #fx.COLORS + 1
  return col
end

function fx.view(rects) view, shown = rects, {} end

function fx.start(k, c, g)
  kind, t, grid, fx.f = k, 0, g, 0
  if c then fx.color(c) end
  if k ~= 0 then return end
  for i = 1, 8 do
    led.hex(i, 0)
    if view then view[i]:color(0x1C1C24) end
  end
  shown = {}
end

function fx.tick(ms)
  if kind == 0 then return end
  t = (t + ms) % 8064000
  local c, p = fx.COLORS[col], PERIOD[kind]
  for i = 1, 8 do
    local v = shade(i, c, p)
    led.hex(i, v)
    if view and shown[i] ~= v then
      shown[i] = v
      view[i]:color(v ~= 0 and v or 0x1C1C24)
    end
  end
  if fx.f > 0 then fx.f = fx.f - ms end
end

return fx
