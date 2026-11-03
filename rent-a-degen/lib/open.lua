local core = require("lib.core")
local scr = {}
local MODES = {
  {"RENT MY BADGE", "Control of your LEDs and screen, by the block", "lib/sell.lua"},
  {"RENT MY PIXELS", "Each of your 8 LEDs has its own price", "lib/pixels.lua"},
  {"AUCTION ME", "The highest bid wins the next slot", "lib/auction.lua"},
}

function scr.enter()
  local rows = {}
  for i, m in ipairs(MODES) do rows[i] = {title = m[1], sub = m[2]} end
  core.title("SELL YOURSELF AS")
  ui.list(0, 28, ui.W, ui.H - 44, rows, {on_select = function(i)
    if i ~= 2 and #core.cfg.o == 0 then return ui.toast("Add an offer first") end
    core.go(MODES[i][3])
  end})
  ui.hint("SELECT open   CANCEL back")
end

function scr.key(k)
  if k == "back" then core.go(core.home) end
  return true
end

return scr
