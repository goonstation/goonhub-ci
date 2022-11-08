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
export RUSTFLAGS="-C target-cpu=native"
export PKG_CONFIG_ALLOW_CROSS=1
#cargo build --all-features --release --target i686-unknown-linux-gnu
cargo build --release --target i686-unknown-linux-gnu --no-default-features --features "acreplace, cellularnoise, dmi, file, git, http, json, log, noise, time, toml, url, batchnoise, hash, worleynoise"

echo "Rust-g update complete"
