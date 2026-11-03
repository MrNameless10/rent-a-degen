local core = require("lib.core")
local owe = core.load("lib/owe.lua")

local function refund()
  local e = (storage.get("owe") or {})[1]
  if not e then return end
  ui.confirm("A rental was cut short.\nRefund " .. e.a .. " !LAMPs to " .. e.n .. "?", function(yes)
    if not yes then
      owe(e.o, e.to, e.n, 0)
      return refund()
    end
    lamps.transfer(e.to, e.a, "rent-a-degen refund", function(ok, res)
      if not ok then return ui.toast("Refund failed: " .. tostring(res)) end
      core.stats.e = core.stats.e - e.a
      core.save()
      owe(e.o, e.to, e.n, 0)
      ui.toast("Refunded " .. e.a .. " !LAMPs")
      refund()
    end)
  end)
end

return refund
