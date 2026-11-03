local core = require("lib.core")

function on_tick(ms)
  if core.nextScr then core.switch() end
  local now = sys.millis()
  core.fx.tick(ms)
  core.net.pump(now)
  local tick = core.scr.tick
  if tick then tick(now, ms) end
end

function on_key(k, rep)
  if core.nextScr then return true end
  local key = core.scr.key
  if key then return key(k, rep) end
  return k ~= "back"
end

function on_mesh(from, msg)
  local on = core.scr.on
  local f = on and type(msg) == "table" and on[msg.t]
  if f then f(from, msg) end
end

function on_exit()
  core.net.closing = true
  local leave = core.scr.leave
  if leave then leave() end
end

core.go(core.home)
core.switch()
