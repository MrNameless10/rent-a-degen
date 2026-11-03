local W = {time = 0, badges = {}, ledger = {}, spent = {}, events = {}, maxInstr = 0, autoPay = true, strict = true}
W.log = function() end

local BUDGET, STEP = 200000, 100

local function later(ms, fn)
  W.events[#W.events + 1] = {at = W.time + ms, fn = fn, n = #W.events}
end

local function enc(v)
  local t = type(v)
  if t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c) return ("\\u%04x"):format(c:byte()) end) .. '"'
  end
  if t ~= "table" then return v == nil and "null" or tostring(v) end
  local parts = {}
  if #v > 0 then
    for i, x in ipairs(v) do parts[i] = enc(x) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  for k, x in pairs(v) do parts[#parts + 1] = enc(tostring(k)) .. ":" .. enc(x) end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function copy(v)
  if type(v) ~= "table" then return v end
  local c = {}
  for k, x in pairs(v) do c[k] = copy(x) end
  return c
end

W.enc, W.copy = enc, copy

local function guarded(b, what, fn, ...)
  local n = 0
  debug.sethook(function()
    n = n + STEP
    if n > BUDGET then error("Script took too long (" .. what .. ")") end
  end, "", STEP)
  local ok, r = pcall(fn, ...)
  debug.sethook()
  if n > W.maxInstr then W.maxInstr, W.maxWhere = n, b.id .. " " .. what end
  if ok then return r end
  if W.strict then error(b.id .. ": " .. tostring(r), 0) end
  b.crash, b.running = tostring(r), false
  W.log(b.id, "CRASH " .. tostring(r))
end

local LIBS = {"assert", "error", "ipairs", "next", "pairs", "pcall", "select", "tonumber", "tostring", "type",
  "xpcall", "getmetatable", "setmetatable", "rawequal", "rawget", "rawlen", "rawset", "string", "table", "math",
  "utf8", "coroutine"}

local function widget(b, kind, props)
  local n = 0
  for _ in pairs(b.objs) do n = n + 1 end
  if n >= 64 then error("too many UI objects") end
  b.order = b.order + 1
  local o = props
  o.kind, o.order, o.shown = kind, b.order, true
  b.objs[o] = true
  return setmetatable(o, b.meta)
end

local function methods(b)
  local m = {}
  function m:text(t) self.label = t end
  function m:color(c) self.col = c end
  function m:pos(x, y) self.x, self.y = x, y end
  function m:size(w, h) self.w, self.h = w, h end
  function m:show(s) self.shown = s end
  function m:remove() b.objs[self] = nil end
  function m:set(v)
    assert(math.type(v) == "integer" and v >= 0 and v <= 100, "bar value " .. tostring(v))
    self.value = v
  end
  function m:items(it) self.list, self.sel = it, #it > 0 and 1 or 0 end
  function m:selected() return self.sel > 0 and self.sel or nil end
  function m:select(i) self.sel = i end
  return {__index = m}
end

local function uiFor(b)
  local ui = {W = 320, H = 218}
  function ui.bg(c) b.bg = c end
  function ui.label(x, y, text, opts)
    assert(type(text) == "string", "label text must be a string")
    return widget(b, "label", {x = x, y = y, label = text, opts = opts or {}})
  end
  function ui.rect(x, y, w, h, opts) return widget(b, "rect", {x = x, y = y, w = w, h = h, opts = opts or {}}) end
  function ui.bar(x, y, w, h, v) return widget(b, "bar", {x = x, y = y, w = w, h = h, value = v}) end
  function ui.list(x, y, w, h, items, opts)
    return widget(b, "list", {x = x, y = y, w = w, h = h, list = items, sel = #items > 0 and 1 or 0, pick = opts and opts.on_select})
  end
  function ui.hint(t) b.hint = t end
  function ui.toast(t)
    b.toasts[#b.toasts + 1], b.toastAt = t, W.time
    W.log(b.id, "toast: " .. t)
  end
  function ui.confirm(t, cb)
    b.modal = {text = t, cb = cb}
    W.log(b.id, "confirm: " .. t:gsub("\n", " | "))
  end
  function ui.input(t, max, cb) b.kb = {text = t, max = max, cb = cb} end
  function ui.clear() b.objs, b.hint, b.bg = {}, nil, nil end
  return ui
end

local function ledFor(b)
  local led = {count = 8}
  function led.set(i, r, g, bl)
    assert(i >= 1 and i <= 8 and r >= 0 and r <= 255 and g >= 0 and g <= 255 and bl >= 0 and bl <= 255,
      ("bad led.set %s %s %s %s"):format(i, r, g, bl))
    b.leds[i] = r << 16 | g << 8 | bl
  end
  function led.hex(i, c) b.leds[i] = c end
  function led.fill(r, g, bl) for i = 1, 8 do led.set(i, r, g, bl) end end
  function led.off() for i = 1, 8 do b.leds[i] = 0 end end
  return led
end

local function meshFor(b)
  local sent = {}
  local mesh = {}
  function mesh.nearby()
    local l = {}
    for id, o in pairs(W.badges) do
      if id ~= b.id then l[#l + 1] = {id = id, name = o.owner or "", level = 1, rssi = -40, kind = "badge", bridged = false} end
    end
    return l
  end
  function mesh.send(to, msg)
    assert(type(msg) == "table", "mesh msg must be a table")
    local s = enc(msg)
    assert(#s <= 200, "mesh message over 200 bytes: " .. s)
    while sent[1] and sent[1] <= W.time - 1000 do table.remove(sent, 1) end
    assert(#sent < 4, b.id .. " sends more than 4 mesh messages a second")
    sent[#sent + 1] = W.time
    W.log(b.id, "-> " .. to .. " " .. s)
    for id, o in pairs(W.badges) do
      if id ~= b.id and (to == "*" or to == id) and o.running and not (W.drop and W.drop(b.id, id, msg)) then
        local m = copy(msg)
        later(5, function()
          if o.running and o.env.on_mesh then guarded(o, "on_mesh", o.env.on_mesh, b.id, m) end
        end)
      end
    end
  end
  return mesh
end

local function lampsFor(b)
  local function call(ms, fn) later(ms, function() if b.running then guarded(b, "lamps cb", fn) end end) end
  return {
    balance = function(cb)
      if not b.online then return call(50, function() cb(false, "offline") end) end
      call(120, function() cb(true, W.ledger[b.id]) end)
    end,
    transfer = function(to, amount, memo, cb)
      assert(math.type(amount) == "integer" and amount > 0, "amount must be 1..1000000")
      assert(#memo <= 64, "memo is at most 64 characters")
      W.log(b.id, ("OS confirm: send %d to %s (%s)"):format(amount, to, memo))
      b.pay = {to = to, amount = amount, cb = cb}
      if W.autoPay then W.osPay(b.id, true) end
    end,
  }
end

function W.badge(id, owner, root, store)
  local b = {id = id, owner = owner, root = root, store = store or {}, objs = {}, toasts = {}, leds = {},
    started = W.time, online = true, order = 0}
  b.meta = methods(b)
  W.badges[id] = b
  W.ledger[id] = W.ledger[id] or 100
  for i = 1, 8 do b.leds[i] = 0 end
  local env = {}
  for _, k in ipairs(LIBS) do env[k] = _G[k] end
  env._G, env.ui, env.led, env.mesh, env.lamps = env, uiFor(b), ledFor(b), meshFor(b), lampsFor(b)
  env.print = function(...) W.log(id, ...) end
  env.collectgarbage = function(o)
    assert(o == "count", "collectgarbage is removed")
    return collectgarbage("count")
  end
  env.timer = {after = function() error("timers not expected") end, every = function() error("timers not expected") end}
  env.sys = {millis = function() return W.time - b.started end, time = function() return 1790000000 + W.time // 1000 end,
    battery = function() return 86 end, exit = function() b.exited = true end}
  env.badge = {id = function() return id end, owner = function() return owner end, online = function() return b.online end}
  env.wifi = {status = function() return b.online and "on" or "off" end, on = function() end, off = function() end,
    ssid = function() return "BP26" end}
  env.json = {encode = enc}
  env.storage = {
    get = function(k) return copy(b.store[k]) end,
    set = function(k, v)
      b.store[k] = copy(v)
      assert(#enc(b.store) <= 16384, "storage over 16 KB")
    end,
    remove = function(k) b.store[k] = nil end,
  }
  env.fs = {load = function(path) return loadfile(root .. path, "t", env) end}
  local loaded = {}
  env.require = function(name)
    if loaded[name] == nil then
      loaded[name] = assert(loadfile(root .. name:gsub("%.", "/") .. ".lua", "t", env))() or true
    end
    return loaded[name]
  end
  b.env = env
  function b.instance()
    b.running = true
    guarded(b, "main chunk", assert(loadfile(root .. "main.lua", "t", env)))
  end
  return b
end

function W.osPay(id, yes)
  local b = W.badges[id]
  local d = b.pay
  if not d then return end
  b.pay = nil
  later(300, function()
    if not b.running then return end
    if not yes then return guarded(b, "lamps cb", d.cb, false, "denied") end
    if (W.spent[id] or 0) + d.amount > 500 then return guarded(b, "lamps cb", d.cb, false, "daily limit") end
    if W.ledger[id] < d.amount then return guarded(b, "lamps cb", d.cb, false, "insufficient") end
    W.ledger[id], W.ledger[d.to] = W.ledger[id] - d.amount, (W.ledger[d.to] or 0) + d.amount
    W.spent[id] = (W.spent[id] or 0) + d.amount
    guarded(b, "lamps cb", d.cb, true, {balance = W.ledger[id]})
  end)
end

local function topList(b)
  local best
  for o in pairs(b.objs) do
    if o.kind == "list" and o.shown and (not best or o.order > best.order) then best = o end
  end
  return best
end

function W.key(id, k, rep)
  local b = W.badges[id]
  assert(not b.kb, "use W.type for the keyboard")
  if b.modal then
    if k == "select" or k == "back" then
      local m = b.modal
      b.modal = nil
      guarded(b, "confirm cb", m.cb, k == "select")
    end
    return
  end
  local l = topList(b)
  if l and (k == "up" or k == "down") then
    if #l.list > 0 then l.sel = math.max(1, math.min(#l.list, l.sel + (k == "up" and -1 or 1))) end
    return
  end
  if l and k == "select" and l.pick and l.sel > 0 then
    return guarded(b, "on_select", l.pick, l.sel, l.list[l.sel])
  end
  if not guarded(b, "on_key", b.env.on_key, k, rep or false) and k == "back" then W.stop(id) end
end

function W.type(id, text)
  local b = W.badges[id]
  local kb = assert(b.kb, "no keyboard open")
  b.kb = nil
  guarded(b, "input cb", kb.cb, text and text:sub(1, kb.max))
end

function W.stop(id)
  local b = W.badges[id]
  if b.env.on_exit then guarded(b, "on_exit", b.env.on_exit) end
  b.running = false
  for i = 1, 8 do b.leds[i] = 0 end
end

function W.run(ms)
  local stop = W.time + ms
  while W.time < stop do
    W.time = W.time + 50
    table.sort(W.events, function(a, c) return a.at < c.at or a.at == c.at and a.n < c.n end)
    while W.events[1] and W.events[1].at <= W.time do table.remove(W.events, 1).fn() end
    for i = 1, #W.events do W.events[i].n = i end
    for _, b in pairs(W.badges) do
      if b.running and b.env.on_tick then guarded(b, "on_tick", b.env.on_tick, 50) end
    end
  end
end

function W.relaunch(id)
  local old = W.badges[id]
  if old.running then W.stop(id) end
  local b = W.badge(id, old.owner, old.root, old.store)
  b.online = old.online
  b.instance()
  return b
end

function W.scene(id)
  local b, objs = W.badges[id], {}
  for o in pairs(b.objs) do
    if o.shown then
      local e = {k = o.kind, n = o.order, x = o.x, y = o.y, w = o.w, h = o.h, t = o.label, o = o.opts, v = o.value, sel = o.sel, col = o.col}
      if o.kind == "list" then
        e.rows = {}
        for i, it in ipairs(o.list) do
          e.rows[i] = type(it) == "table" and {it.title or "", it.sub or "", it.right or ""} or {tostring(it), "", ""}
        end
      end
      objs[#objs + 1] = e
    end
  end
  table.sort(objs, function(a, c) return a.n < c.n end)
  return {id = id, owner = b.owner, running = b.running or false, crash = b.crash, online = b.online, hint = b.hint,
    objs = objs, leds = b.leds, lamps = W.ledger[id], modal = b.modal and b.modal.text, kb = b.kb and {b.kb.text, b.kb.max},
    pay = b.pay and {b.pay.amount, b.pay.to}, toast = b.toastAt and W.time - b.toastAt < 2500 and b.toasts[#b.toasts] or nil}
end

function W.texts(id)
  local t = {}
  for o in pairs(W.badges[id].objs) do
    if o.kind == "label" then t[#t + 1] = o.label end
  end
  return table.concat(t, " | ")
end

function W.rows(id)
  local l, r = topList(W.badges[id]), {}
  for i, it in ipairs(l and l.list or {}) do
    r[i] = type(it) == "table" and it.title .. (it.sub and " (" .. it.sub .. ")" or "") .. (it.right and " [" .. it.right .. "]" or "") or it
  end
  return r
end

function W.lit(id)
  local n = 0
  for _, c in ipairs(W.badges[id].leds) do
    if c ~= 0 then n = n + 1 end
  end
  return n
end

return W
