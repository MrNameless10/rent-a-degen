local here = arg[0]:match("^(.*)/") or "."
package.path = here .. "/?.lua;" .. package.path
local W = require("badge")
local ROOT = here .. "/../rent-a-degen/"
local verbose = arg[1] == "-v"
local fails, checks, sendErrors = 0, 0, 0
local S, A, B = "MIG001", "ALX002", "SAR003"

W.log = function(id, ...)
  local s = table.concat({...}, " ")
  if s:find("^mesh:") then
    sendErrors = sendErrors + 1
    print("!! " .. id .. " " .. s)
  end
  if verbose then print(("%8d %s %s"):format(W.time, id, s)) end
end

local function check(cond, what)
  checks = checks + 1
  if cond then print("  ok   " .. what) else fails = fails + 1 print("  FAIL " .. what) end
end

local function has(id, s) return W.texts(id):find(s, 1, true) ~= nil end
local function run(ms) W.run(ms or 100) end
local function press(id, ...) for _, k in ipairs({...}) do W.key(id, k) end end
local function core(id) return W.badges[id].env.require("lib.core") end
local function store(id) return W.badges[id].store end
local function lit(id, i) return W.badges[id].leds[i] end

local function openShop(mode)
  press(S, "select")
  run(100)
  for _ = 2, mode do press(S, "down") end
  press(S, "select")
  run(300)
end

local function browse(id)
  press(id, "right")
  run(2500)
end

for _, b in ipairs({{S, "@miguel"}, {A, "@alex"}, {B, "@sarah"}}) do W.badge(b[1], b[2], ROOT).instance() end
run(200)

print("Home")
check(has(S, "@MIGUEL") and has(S, "PEOPLE ARE THE PRODUCT"), "home shows @MIGUEL")
check(W.lit(S) == 8, "the pixel badge and the LEDs breathe")

print("Rent my badge, by the block")
openShop(1)
check(has(S, "FOR SALE") and has(S, "Waiting for degens"), "shop is open")
browse(A)
local rows = W.rows(A)
check(rows[1] and rows[1]:find("@miguel", 1, true) and rows[1]:find("[rent]", 1, true) and rows[1]:find("3 offers, from 2 !L", 1, true),
  "buyer sees the shop: " .. tostring(rows[1]))
press(A, "select")
run(3000)
rows = W.rows(A)
check(#rows == 3 and rows[1]:find("RUG PULL", 1, true) and rows[1]:find("[3 !L/10s]", 1, true) and rows[1]:find("up to 5m", 1, true),
  "menu: " .. table.concat(rows, ", "))
press(A, "select")
check(has(A, "< 1 x 10s = 10s >") and has(A, "3 !LAMPs"), "time picker starts at one block")
press(A, "right", "right")
check(has(A, "< 3 x 10s = 30s >") and has(A, "9 !LAMPs"), "three blocks cost 9")
press(A, "select")
run(5000)
check(W.ledger[S] == 109 and W.ledger[A] == 91, "9 !LAMPs paid: " .. W.ledger[S] .. "/" .. W.ledger[A])
check(has(S, "BADGE CONTROLLED BY") and has(S, "@ALEX"), "seller is controlled by @ALEX")
check(has(A, "YOU OWN") and has(A, "@MIGUEL"), "buyer owns @MIGUEL")
check(store(S).owe and store(S).owe[1].a == 9, "refund note held while the rental runs")
press(A, "select")
run(150)
check(lit(S, 1) == 0xFFFFFF, "flash turns the seller white")
run(30000)
check(has(A, "Your time is up"), "buyer told the time is up")
check(has(S, "FOR SALE"), "seller back to the shop")
check(store(S).owe == nil, "no refund owed after a full rental")
check(store(S).st.e == 9 and store(S).st.r == 1 and store(S).st.last[1] == "@alex", "seller stats")
check(store(A).st.s == 9 and store(A).st.b == 1, "buyer stats")

print("Buyer's text, approval, early end")
press(A, "select")
run(2500)
press(A, "select")
run(3000)
press(A, "down", "down", "select", "select")
W.type(A, "gm\nfrom Lisbon")
run(1000)
check(W.badges[S].modal and W.badges[S].modal.text:find("gm from Lisbon", 1, true), "seller asked to approve the text")
run(4000)
check(has(A, "approve"), "buyer told the seller is approving")
press(S, "select")
run(4000)
check(has(S, "A MESSAGE FROM") and has(S, "gm from Lisbon"), "seller shows the text")
check(W.ledger[S] == 119, "10 more !LAMPs: " .. W.ledger[S])
run(15000)
press(S, "back", "select")
run(2000)
check(W.ledger[S] >= 113 and W.ledger[S] <= 116, "about half refunded: " .. W.ledger[S])
check(has(A, "Ended early"), "buyer told it ended early")
check(store(S).owe == nil, "nothing left owing")

print("A liar")
W.autoPay = false
local before = W.ledger[S]
W.badges[B].env.mesh.send(S, {t = "o", o = 4242, k = 1, q = 1, p = 3})
run(1500)
W.badges[B].env.mesh.send(S, {t = "P", o = 4242})
run(20000)
check(W.ledger[S] == before and not has(S, "CONTROLLED"), "no control without payment")
check(has(S, "unpaid"), "seller logs the unpaid order")
W.autoPay = true

print("Garbage on the mesh")
local junk = {
  {t = "o", k = "x", q = {}, p = 1, o = 1}, {t = "o", k = 1, q = 0, p = 0, o = 9}, {t = "c", o = 1, c = 1.5},
  {t = "h", m = 9, n = "3", lo = {}}, {t = "i", k = 1, n = {}, p = 1, s = 1, q = 1, f = 1, c = 1, x = 9},
  {t = "e", c = -1}, {t = "z", o = 1, m = "9"}, {t = "X", p = {1}, u = "x"}, {t = "A", n = 1}, {t = "B", o = 1, v = 9999},
  {t = "$", o = 1, p = -1}, {t = "g", o = 1, d = {}}, {t = "E", o = 1}, {t = 5}, {}, {t = {}}, {t = "l"}, {t = "?"},
}
for _, m in ipairs(junk) do
  for _, id in ipairs({S, A, B}) do W.badges[id].env.on_mesh("ZZZ999", W.copy(m)) end
end
run(2000)
check(W.badges[S].running and W.badges[A].running and W.badges[B].running, "every badge survived " .. #junk .. " bad messages")

print("Payment cancelled on the OS dialog")
press(A, "select")
run(2500)
press(A, "select")
run(3000)
W.autoPay = false
press(A, "select", "select")
run(3000)
check(W.badges[A].pay ~= nil, "OS payment dialog is up")
W.osPay(A, false)
run(4000)
check(table.concat(W.badges[A].toasts, "|"):find("Payment cancelled", 1, true), "buyer sees Payment cancelled")
check(has(S, "cancelled"), "seller is free again")
W.autoPay = true

print("Seller quits mid-rental")
press(A, "select", "right", "right", "select")
run(4000)
check(has(S, "CONTROLLED BY"), "rental running")
run(15000)
W.stop(S)
local owed = store(S).owe and store(S).owe[1].a
check(owed and owed >= 3 and owed <= 5, "owes about half of 9: " .. tostring(owed))
run(500)
check(has(A, "They left the app"), "buyer told the seller left")
local paidBefore = W.ledger[A]
W.relaunch(S)
check(W.badges[S].modal and W.badges[S].modal.text:find("Refund", 1, true), "seller asked to refund on launch")
press(S, "select")
run(1000)
check(W.ledger[A] == paidBefore + owed and store(S).owe == nil, "refund paid: " .. paidBefore .. " -> " .. W.ledger[A])

print("My prices")
press(S, "left")
run(100)
press(S, "select", "down", "down", "down", "down", "right")
W.key(S, "right", true)
press(S, "down", "left", "back")
local o1 = core(S).cfg.o[1]
check(o1.p == 9 and o1.q == 29, "RUG PULL now 9 !L a block, 29 blocks: " .. o1.p .. "/" .. o1.q)
press(S, "select", "select")
W.type(S, "touch grass")
press(S, "back")
check(core(S).cfg.o[1].n == "TOUCH GRASS", "renamed")
rows = W.rows(S)
check(rows[#rows]:find("Add an offer", 1, true), "add an offer is the last row: " .. rows[#rows])
press(S, "down", "down", "down", "select", "right", "back")
check(core(S).cfg.px.p[1] == 6, "pixel 1 now 6 !L")
press(S, "down", "down", "down", "down", "select", "down", "right", "back")
check(core(S).cfg.au.r == 6, "auction reserve now 6 !L")
press(S, "back")
run(100)
check(has(S, "PEOPLE ARE THE PRODUCT"), "back home")
check(store(S).v1.o[1].n == "TOUCH GRASS", "prices saved")

print("Pixel landlord")
core(S).cfg.px.s = 120
openShop(2)
check(has(S, "PIXEL LANDLORD  0/8"), "pixel shop is open")
press(A, "back")
run(100)
browse(A)
check(W.rows(A)[1]:find("8/8 pixels free, from 5 !L", 1, true), "buyer sees free pixels: " .. W.rows(A)[1])
press(A, "select")
run(3000)
rows = W.rows(A)
check(#rows == 8 and rows[1]:find("[6 !L/2m]", 1, true), "pixel list: " .. tostring(rows[1]))
press(A, "select", "right", "down", "right", "right")
check(has(A, "< pink >") and has(A, "12 !LAMPs"), "two blocks, pink")
browse(B)
press(B, "select")
run(3000)
press(B, "down", "select")
press(A, "select")
press(B, "select")
run(8000)
check(lit(S, 1) == 0xFF3EA5, "pixel 1 is pink on the seller")
check(lit(S, 2) == 0x9945FF, "pixel 2 is purple (queued order went through)")
check(has(S, "PIXEL LANDLORD  2/8") and has(S, "@alex") and has(S, "@sarah"), "landlord lists both tenants")
press(A, "right")
run(1000)
check(lit(S, 1) == 0x00C2FF, "tenant recolours pixel 1 blue")
for i = 3, 8 do
  press(B, "back")
  run(3500)
  for _ = 1, i - 1 do press(B, "down") end
  press(B, "select", "select")
  run(6000)
end
check(has(S, "100% COMMUNITY-OWNED"), "all 8 pixels rented")
run(250000)
check(has(A, "Your time is up") and has(S, "PIXEL LANDLORD  0/8"), "leases expire, pixels free again")
check(store(S).owe == nil, "no refunds owed after the leases")

print("Auction")
press(S, "back")
run(100)
openShop(3)
check(has(S, "HOSTILE TAKEOVER") and has(S, "6 !L"), "auction open at the 6 !L reserve")
press(A, "select")
run(2500)
press(A, "select")
run(3000)
press(B, "back")
run(3000)
press(B, "back")
run(100)
browse(B)
press(B, "select")
run(3000)
check(has(A, "AUCTION: @MIGUEL") and has(A, "< 6 !L >"), "bidder sees the reserve")
press(A, "select", "select")
run(1500)
check(has(A, "You're winning") and has(S, "@alex bids 6"), "first bid accepted")
press(B, "right", "select", "select")
run(1500)
check(has(B, "You're winning") and has(A, "Outbid!"), "outbid")
run(35000)
press(A, "right", "select", "select")
run(1000)
check(has(A, "You're winning"), "late bid accepted")
run(8000)
check(has(S, "@alex bids 10") and not has(S, "CONTROLLED"), "anti-sniping kept the auction open past 60s")
run(12000)
check(has(S, "BADGE CONTROLLED BY") and has(S, "@ALEX"), "winner takes control")
check(has(B, "Won by @alex"), "loser told who won")
run(61000)
check(has(S, "HOSTILE TAKEOVER") and has(A, "Your time is up"), "auction reopens after the slot")
press(A, "select")
run(2500)
press(A, "select")
run(3000)
press(B, "select", "select")
run(1500)
press(A, "select", "select")
W.autoPay = false
run(62000)
check(W.badges[A].pay, "winner gets the payment dialog")
W.osPay(A, false)
run(4000)
check(W.badges[B].pay, "second bidder asked to pay instead")
W.osPay(B, true)
run(5000)
check(has(S, "@SARAH") and has(B, "YOU OWN"), "second bidder takes control")
W.autoPay = true

print("Limits")
check(sendErrors == 0, "no mesh send errors")
check(W.maxInstr < 200000, ("worst callback ~%d instructions (%s)"):format(W.maxInstr, W.maxWhere))
print(("\n%d checks, %s"):format(checks, fails == 0 and "ALL PASSED" or fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
