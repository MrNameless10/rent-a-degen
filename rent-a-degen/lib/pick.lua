local core = require("lib.core")
local text = core.text
local fx = core.fx

return function(title, s, p, q, colour, done)
  local max = math.min(q, core.CAP // p)
  local n, c, row = 1, 1, 1
  core.title(title)
  local mark = ui.rect(4, 38, 3, 18, {color = 0x14F195})
  text(14, 40, "TIME", 12, "dim")
  local time = text(90, 38, "", 14)
  text(14, 70, "PRICE", 12, "dim")
  local cost = text(90, 64, "", 20, "green")
  text(14, 100, "BLOCK", 12, "dim")
  text(90, 100, core.dur(s) .. " for " .. p .. " !L, up to " .. max, 12, "dim")
  local hue
  if colour then
    text(14, 130, "COLOUR", 12, "dim")
    hue = text(90, 128, "", 14)
  end
  ui.hint(colour and "UP/DOWN row  LEFT/RIGHT change  SELECT buy" or "LEFT/RIGHT time   SELECT buy   CANCEL back")

  local function show()
    time:text("< " .. n .. " x " .. core.dur(s) .. " = " .. core.dur(n * s) .. " >")
    cost:text(n * p .. " !LAMPs")
    mark:pos(4, row == 1 and 38 or 128)
    if hue then
      hue:text("< " .. fx.CNAMES[c] .. " >")
      hue:color(fx.COLORS[c])
    end
  end

  show()
  return function(k, rep)
    if k == "select" then return done(n, c) end
    if k == "back" then return done() end
    local d = (k == "right" and 1 or k == "left" and -1 or 0) * (rep and 5 or 1)
    if colour and (k == "up" or k == "down") then
      row = 3 - row
    elseif d == 0 then
      return
    elseif row == 1 then
      n = math.max(1, math.min(max, n + d))
    else
      c = (c - 1 + (d > 0 and 1 or -1)) % #fx.COLORS + 1
    end
    show()
  end
end
