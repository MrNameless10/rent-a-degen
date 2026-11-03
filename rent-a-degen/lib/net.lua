local net = {}
local N, GAP = 12, 280
local dest, body = {}, {}
local head, size, nextAt = 1, 0, 0

function net.send(to, msg)
  if net.closing then return pcall(mesh.send, to, msg) end
  if size == N then return false end
  local i = (head + size - 1) % N + 1
  dest[i], body[i], size = to, msg, size + 1
  return true
end

function net.idle() return size == 0 end

function net.pump(now)
  if size == 0 or now < nextAt then return end
  local ok, err = pcall(mesh.send, dest[head], body[head])
  if not ok then print("mesh: " .. tostring(err)) end
  dest[head], body[head] = nil, nil
  head, size, nextAt = head % N + 1, size - 1, now + GAP
end

return net
