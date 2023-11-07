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

# Set cdn grouping from server ID
d_log "Setting CDN group"
cdn_group="main"
[[ "$server_id" == dev* ]] && cdn_group="dev"
[[ "$server_id" == streamer* ]] && cdn_group="streamer"
[[ "$server_id" == main5 ]] && cdn_group="event"

cd /home/ss13/cdn-build
if [ ! -d "$cdn_group" ]; then
	d_log "CDN group dir not found, creating it"
	mkdir "$cdn_group"
fi

# Prevent concurrent builds in the same CDN group
if [ -f "$cdn_group.lock" ]; then
	d_log "Already building this CDN, exiting"
	exit
fi
touch "$cdn_group.lock"

# Merge secret browserassets into regular browserassets
if [ -d "$build_dir/+secret/browserassets" ]; then
	d_log "Merging secret browserassets in"
	rsync -a "$build_dir/+secret/browserassets/" "$build_dir/browserassets/"
fi

# Save some build time by skipping CDN builds if there's nothing new
d_log "Running browserassets diff"
cdn_diff=$(diff -qr -x node_modules -x build -x revision -x package-lock.json "$cdn_group" "$build_dir/browserassets" || true)
if [ -z "$cdn_diff" ]; then
	d_log "Browserassets hasn't changed, skipping CDN build"
	rm "$cdn_group.lock" >/dev/null 2>&1 || true
	exit
fi

cd "$cdn_group"
d_log "Clearing old browserassets"
[ -d "node_modules" ] && mv node_modules "../$cdn_group.node_modules"
rm -r * >/dev/null 2>&1 || true
[ -d "../$cdn_group.node_modules" ] && mv "../$cdn_group.node_modules" node_modules
d_log "Copying new browserassets"
cp -R "$build_dir/browserassets/"* .

d_log "Running browserassets compilation"
git -C "$repo_dir" rev-parse HEAD > revision

# Just for now for testing
if [ "$cdn_group" = "dev" ]; then
	npm install --no-progress >/dev/null 2>&1
	npm run build --servertype=$cdn_group >/dev/null 2>&1
else
	n exec 10.16.0 npm install --no-progress >/dev/null 2>&1
	grunt build-cdn --servertype=$cdn_group >/dev/null 2>&1
fi

d_log "Copying built files to pre-deploy"
cp -r build "/ss13_servers/$server_id/deploy/cdn"

cd ..
rm "$cdn_group.lock" >/dev/null 2>&1 || true

d_log "Finished CDN update"
