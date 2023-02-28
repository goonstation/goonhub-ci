#!/bin/bash
set -e

cd /rust-g/goonstation-rust-g/target/i686-unknown-linux-gnu/release

cp librust_g.so /remote_ss13/servers/main1/game/update
cp librust_g.so /remote_ss13/servers/main2/game/update
cp librust_g.so /remote_ss13/servers/main3/game/update
cp librust_g.so /remote_ss13/servers/main4/game/update
cp librust_g.so /remote_ss13/servers/dev/game/update
