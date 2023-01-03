#!/bin/bash
set -e
shopt -s extglob
source utilities.sh
server_id="$1"
cd "/ss13_servers/$server_id/deploy"

d_log "Running deployment"

# Set CDN group from server ID
d_log "Setting CDN group"
cdn_group="main"
[[ "$server_id" == dev* ]] && cdn_group="dev"
[[ "$server_id" == streamer* ]] && cdn_group="streamer"
[[ "$server_id" == main5 ]] && cdn_group="event"

# Move any new byond files to remote
rsync -ar --ignore-existing /byond/* /remote_ss13/byond

# Prepare and move rsc zip to CDN
if [ -f "goonstation.rsc" ]; then
	d_log "Uploading new rsc to cdn"
	zip -q rsc.zip goonstation.rsc
	mv rsc.zip "/goonhub_cdn/public/$cdn_group" >/dev/null 2>&1 || true
fi

# Move any new CDN files
if [ -d "cdn" ]; then
	d_log "Uploading new assets to cdn"
	rsync -rl cdn/* "/goonhub_cdn/public/$cdn_group"
	rm -r cdn
fi

# Move any remaining built files to the remote game update folder
d_log "Uploading new assets to game directory"
rm -r /remote_ss13/servers/$server_id/game/update/* >/dev/null 2>&1 || true
mv * /remote_ss13/servers/$server_id/game/update

d_log "Finished deployment"
