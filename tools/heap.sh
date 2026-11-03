#!/bin/sh
set -e
cd "$(dirname "$0")/.."
out="${TMPDIR:-/tmp}/rad-heap"
cc -O2 -o "$out" tools/heap.c $(pkg-config --cflags --libs lua5.5 2>/dev/null || echo "-I/opt/homebrew/include/lua5.5 -L/opt/homebrew/opt/lua/lib -llua") -lm
cd rent-a-degen
base="main.lua lib/core.lua lib/fx.lua lib/net.lua"
while read -r name deps; do
  "$out" "$name" $base $deps
done <<EOF
home lib/home.lua
open lib/open.lua
sell lib/sell.lua lib/counter.lua
owned lib/owned.lua lib/counter.lua
pixels lib/pixels.lua lib/counter.lua
auction lib/auction.lua lib/counter.lua
buy lib/buy.lua
menu lib/menu.lua lib/pick.lua
pixbuy lib/pixbuy.lua lib/pick.lua
bid lib/bid.lua
rent lib/rent.lua
control lib/control.lua
edit lib/edit.lua lib/form.lua
EOF
