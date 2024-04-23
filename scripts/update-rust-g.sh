#!/bin/bash
set -e
source utilities.sh

d_log "Updating rust-g"
cd /rust-g

# Prevent concurrent builds
if [ -f ~/rust-build.lock ]; then
	d_log "Already building rust-g, exiting"
	exit
fi

d_log "Fetching latest version"
git fetch

if [ $(git rev-parse HEAD) = $(git rev-parse @{u}) ]; then
	d_log "Rust-g has no updates, exiting"
	exit
fi

touch ~/rust-build.lock

git reset --hard origin/master

#d_log "Applying patches"
#./apply_patches.sh

d_log "Compiling rust-g"
/home/ss13/.cargo/bin/rustup target add i686-unknown-linux-gnu
/home/ss13/.cargo/bin/rustup update
#cd goonstation-rust-g
export RUSTFLAGS="-C target-cpu=native"
export PKG_CONFIG_ALLOW_CROSS=1
/home/ss13/.cargo/bin/cargo build --release --target i686-unknown-linux-gnu

rm ~/rust-build.lock >/dev/null 2>&1 || true

d_log "Rust-g update complete"
