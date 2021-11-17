#!/bin/bash
set -e
server_id="$1"
rust_g_build="/rust-g/target/i686-unknown-linux-gnu/release/librust_g.so"

cd "/ss13_servers/$server_id"

if cmp -s "$rust_g_build" "game/librust_g.so"; then
	echo "Rust-g is latest, skipping update"
else
	echo "Updating rust-g"
	cp "$rust_g_build" "game/update"
fi

echo "Updated rust-g!"
