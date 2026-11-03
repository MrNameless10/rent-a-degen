# Rent-a-Degen mesh protocol

Every message is a small table with a one-letter type `t`, sent with `mesh.send`
(≤ 200 bytes as JSON, ≤ 4 per second; `lib/net.lua` paces them through a fixed
ring buffer). `o` is an order id the buyer picks (1..999999). Each side ignores
messages for an order that isn't its current one, and every field from the mesh
is range-checked before use (`core.int`, `core.clean`).

A shop runs in one of three modes at a time: `m = 1` rent my badge, `m = 2` rent my
pixels, `m = 3` auction.

## Discovery

| From → to | Message | Meaning |
|---|---|---|
| buyer → `*` | `{t="?"}` | who is selling? |
| seller → `*` / buyer | `{t="h", m, n, lo, b}` | shop open in mode `m`; `n` offers / free pixels / bids; `lo` cheapest price or next bid; `b=1` rented or closed. Every 4 s |
| seller → `*` | `{t="x"}` | shop closed |
| buyer → seller | `{t="l"}` | send me your menu |

## Rent my badge (`m = 1`)

Offers are sold by the block: `s` seconds for `p` !LAMPs, up to `q` blocks.

| From → to | Message |
|---|---|
| seller → buyer | `{t="i", k, n, f, c, s, p, q, x}` one offer: index, name, effect, colour, block seconds, price per block, max blocks, screen text mode |
| seller → buyer | `{t="e", c}` end of menu, `c` offers |
| buyer → seller | `{t="o", o, k, q, p, m?}` order `q` blocks of offer `k` for `p` = price × `q`; `m` the buyer's text |

## Rent my pixels (`m = 2`)

| From → to | Message |
|---|---|
| seller → buyer | `{t="X", p=[8], s, q, u=[8]}` price of each LED per block, block seconds, max blocks, colour index of each LED (0 = free) |
| buyer → seller | `{t="o", o, k, q, p, c}` rent pixel `k` for `q` blocks in colour `c` |

Pixels are rented concurrently, but payments are checked one at a time: an order
that arrives while another is being paid gets `{t="r", w="queue"}` and the buyer
retries after a randomised 0.8–2.4 s backoff.

## Auction (`m = 3`)

| From → to | Message |
|---|---|
| seller → `*` | `{t="A", n, f, c, d, l, r, i, h, w, b, e, k, s}` offer name, effect, colour, slot seconds, bidding seconds, reserve, minimum raise, highest bid, its badge id and name, ms left, bid count, state (1 open, 2 settling, 3 over). Every 2 s and on each bid |
| buyer → seller | `{t="B", o, v}` bid `v`; refused with `{t="r", w="low"}` or `w="closed"` |

A bid in the last 10 s extends the auction to 10 s (anti-sniping). The ranking is a
list kept in descending order: each accepted bid is higher than every other, so it
goes on top in O(1) and the bidder's older bid is dropped. At the close the top
bidder is asked to pay; if they don't, the next one is, and so on.

## Paying and control (every mode)

```
buyer                         seller
  o  {k, q, p, ...} ───────▶   checks the price, not busy, online
                    ◀───────   w  {o}       waiting for the seller to approve the text
                    ◀───────   $  {o, p}    balance snapshot taken: pay now (every 3 s)
  lamps.transfer(seller, p)    OS confirm dialog on the buyer's badge
  P  {o}            ───────▶   polls lamps.balance until it grew by p (8 tries, 2 s apart)
                    ◀───────   g  {o, d}    paid: d ms of control
                    ◀───────   z  {o, m}    every 3 s: m ms left (badge rentals)
  c  {o, c}  b {o}  ───────▶   recolour, white flash
                    ◀───────   E  {o, w}    over: done, early, quit
```

Rejections: `{t="r", o, w}` with `w` = `busy`, `changed`, `declined`, `offline`,
`timeout`, `unpaid`, `taken`, `closed`, `queue`. The buyer cancels before paying
with `{t="n", o}`. Messages can be lost, so the buyer repeats `o` (5 × 3 s) and `P`
(30 × 2 s), and the seller repeats `$` and `w`.

## Why the seller can trust a payment

Checkouts run one at a time (`lib/counter.lua`). The seller reads its balance right
before asking for `$` and only hands over control once the balance has grown by at
least the price, so a buyer who lies about paying gets `unpaid`. Unrelated income
during that window could pass for a payment: the seller loses a few seconds of
LEDs, nobody loses !LAMPs. If the seller's app closes mid-rental, what is still owed
is stored and offered as a refund on the next launch.
