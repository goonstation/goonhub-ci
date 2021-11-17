#!/bin/bash
set -e
server_id="$1"
repo_dir="/ss13_servers/$server_id/repo"
echo "Updating CDN..."

if [ -z "$server_id" ]; then
	echo "No server ID provided, unable to build CDN"
	exit
fi

# Set cdn grouping from server ID
cdn_group="main"
[[ "$server_id" == dev* ]] && cdn_group="dev"
[[ "$server_id" == streamer* ]] && cdn_group="streamer"

cd /home/ss13/cdn-build
if [ ! -d "$cdn_group" ]; then
	mkdir "$cdn_group"
fi

# Save some build time by skipping CDN builds if there's nothing new
cdn_diff=$(diff -qr -x node_modules -x build -x revision -x package-lock.json "$cdn_group" "$repo_dir/browserassets" || true)
if [ -z "$cdn_diff" ]; then
	echo "Browserassets hasn't changed, skipping CDN build"
	exit
fi

# Prevent concurrent builds in the same CDN group
if [ -f "$cdn_group.lock" ]; then
	echo "Already building this CDN"
	exit
fi
touch "$cdn_group.lock"

cd "$cdn_group"
echo "Clearing old browserassets..."
[ -d "node_modules" ] && mv node_modules "../$cdn_group.node_modules"
rm -r * >/dev/null 2>&1 || true
[ -d "../$cdn_group.node_modules" ] && mv "../$cdn_group.node_modules" node_modules
echo "Copying new browserassets..."
cp -R "$repo_dir/browserassets/"* .

echo "Running browserassets compilation..."
git -C "$repo_dir" rev-parse HEAD > revision
n exec 10.16.0 npm install --no-progress
grunt build-cdn --servertype=$cdn_group >/dev/null 2>&1

echo "Deploying built browserassets to CDN..."
rsync -hrl build/* "/goonhub_cdn/public/$cdn_group"

cd ..
rm "$cdn_group.lock"
echo "CDN updated!"
