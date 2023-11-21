#!/bin/bash
set -e
source utilities.sh
server_id="$1"
repo_dir="/ss13_servers/$server_id/repo"
build_dir="/ss13_servers/$server_id/build"

d_log "Running CDN update"

if [ -z "$server_id" ]; then
	d_log "No server ID provided, unable to build CDN, exiting"
	exit
fi

cd /home/ss13/cdn-build
if [ ! -d "$server_id" ]; then
	d_log "CDN group dir not found, creating it"
	mkdir "$server_id"
fi

# Prevent concurrent builds in the same CDN group
if [ -f "$server_id.lock" ]; then
	d_log "Already building this CDN, exiting"
	exit
fi
touch "$server_id.lock"

# Merge secret browserassets into regular browserassets
if [ -d "$build_dir/+secret/browserassets" ]; then
	d_log "Merging secret browserassets in"
	rsync -a "$build_dir/+secret/browserassets/" "$build_dir/browserassets/"
fi

# Save some build time by skipping CDN builds if there's nothing new
d_log "Running browserassets diff"
cdn_diff=$(diff -qr -x node_modules -x build -x revision -x package-lock.json "$server_id" "$build_dir/browserassets" || true)
if [ -z "$cdn_diff" ]; then
	d_log "Browserassets hasn't changed, skipping CDN build"
	rm "$server_id.lock" >/dev/null 2>&1 || true
	exit
fi

cd "$server_id"
d_log "Clearing old browserassets"
[ -d "node_modules" ] && mv node_modules "../$server_id.node_modules"
rm -r * >/dev/null 2>&1 || true
[ -d "../$server_id.node_modules" ] && mv "../$server_id.node_modules" node_modules
d_log "Copying new browserassets"
cp -R "$build_dir/browserassets/"* .

d_log "Running browserassets compilation"
git -C "$repo_dir" rev-parse HEAD > revision
npm install --no-progress >/dev/null 2>&1
npm run build -- --servertype "$server_id" >/dev/null 2>&1

d_log "Copying built files to pre-deploy"
cp -r build "/ss13_servers/$server_id/deploy/cdn"

cd ..
rm "$server_id.lock" >/dev/null 2>&1 || true

d_log "Finished CDN update"
