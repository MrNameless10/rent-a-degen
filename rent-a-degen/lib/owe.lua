return function(o, to, n, a)
  local list = storage.get("owe") or {}
  for i = #list, 1, -1 do
    if list[i].o == o then table.remove(list, i) end
  end
  if a > 0 then list[#list + 1] = {o = o, to = to, n = n, a = a} end
  if #list > 0 then storage.set("owe", list) else storage.remove("owe") end
end
