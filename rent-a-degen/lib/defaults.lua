local function offer(n, f, c, s, p, q, x)
  return {n = n, f = f, c = c, s = s, p = p, q = q, x = x}
end

return function()
  return {
    o = {offer("RUG PULL", 2, 7, 10, 3, 30, 1), offer("RAINBOW ME", 3, 1, 10, 2, 60, 1), offer("SPONSOR ME", 7, 2, 30, 10, 20, 3)},
    px = {p = {5, 5, 5, 5, 5, 5, 8, 8}, s = 30, q = 20},
    au = {k = 1, r = 5, i = 1, d = 60, l = 60},
    ap = true,
  }
end
