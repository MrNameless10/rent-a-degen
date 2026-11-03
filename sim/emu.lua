package.path = "/sim/?.lua;" .. package.path
local W = require("badge")

W.strict, W.autoPay = false, false

local log, MAXLOG = {}, 80
local SHOWN = {"^%-> ", "^OS confirm", "^toast", "^CRASH", "^mesh"}

W.log = function(id, ...)
  local s = table.concat({...}, " ")
  for _, p in ipairs(SHOWN) do
    if s:find(p) then
      log[#log + 1] = ("%6.1fs %s %s"):format(W.time / 1000, id, s)
      if #log > MAXLOG then table.remove(log, 1) end
      return
    end
  end
end

local IDS = {"MIG001", "ALX002", "SAR003"}
for i, owner in ipairs({"@miguel", "@alex", "@sarah"}) do W.badge(IDS[i], owner, "/app/").instance() end

local function try(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then W.log("emu", "CRASH " .. tostring(err)) end
end

function emu_step(ms) try(W.run, ms) end

function emu_key(id, k, rep)
  local b = W.badges[id]
  if b.running and not b.kb and not b.pay then try(W.key, id, k, rep) end
end

function emu_type(id, text)
  if W.badges[id].kb then try(W.type, id, text or nil) end
end

function emu_pay(id, yes)
  if W.badges[id].pay then try(W.osPay, id, yes) end
end

function emu_relaunch(id) try(W.relaunch, id) end

function emu_online(id, on) W.badges[id].online = on end

function emu_state()
  local s = {t = W.time, badges = {}, log = log}
  for i, id in ipairs(IDS) do s.badges[i] = W.scene(id) end
  return W.enc(s)
end
