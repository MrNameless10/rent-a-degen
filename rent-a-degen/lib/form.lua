local core = require("lib.core")

return function(title, fields, changed)
  local list

  local function row(f)
    local v = f.t and f.t[f.k]
    local s = f.enum and f.enum[v] or f.text and v or v and v .. (f.unit or "")
    return {title = f.label, right = s and (f.text and s or "< " .. s .. " >")}
  end

  local function refresh()
    local rows, sel = {}, list:selected()
    for i, f in ipairs(fields) do rows[i] = row(f) end
    list:items(rows)
    if sel then list:select(sel) end
  end

  core.title(title)
  list = ui.list(0, 28, ui.W, ui.H - 44, {}, {on_select = function(i)
    local f = fields[i]
    if f.action then return f.action() end
    if not f.text then return end
    ui.input(f.label, f.text, function(s)
      s = core.clean(s, f.text)
      if not s then return end
      f.t[f.k] = s:upper()
      refresh()
    end)
  end})
  ui.hint("LEFT/RIGHT change   SELECT edit   CANCEL save")
  refresh()

  return function(k, rep)
    local f = fields[list:selected() or 0]
    if not f or not f.t or f.text or (k ~= "left" and k ~= "right") then return end
    local d, v = k == "left" and -1 or 1, f.t[f.k]
    if f.enum then
      v = (v - 1 + d) % #f.enum + 1
    else
      v = math.max(f.min, math.min(f.max, v + d * f.step * (rep and 5 or 1)))
    end
    f.t[f.k] = v
    refresh()
    if changed then changed() end
  end
end
