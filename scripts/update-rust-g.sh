#!/bin/bash
set -e

echo "Updating rust-g"
cd /rust-g

echo "Fetching latest version"
git fetch
git reset --hard origin/master

echo "Compiling rust-g"
rustup target add i686-unknown-linux-gnu
rustup update
cd goonstation-rust-g
export RUSTFLAGS="-C target-cpu=native"
export PKG_CONFIG_ALLOW_CROSS=1
./apply_patches.sh
cargo build --release --target i686-unknown-linux-gnu

echo "Rust-g update complete"
