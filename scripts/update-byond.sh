#!/bin/bash
set -e
source utilities.sh
server_id="$1"

d_log "Running BYOND update check"

cd "/ss13_servers/$server_id/repo"
source buildByond.conf
byond_folder="$BYOND_MAJOR_VERSION.$BYOND_MINOR_VERSION"

cd /byond
d_log "Checking for existing BYOND install"
if [ ! -d "$byond_folder" ]; then
	d_log "No install found, downloading new version"
	zip_file="${BYOND_MAJOR_VERSION}.${BYOND_MINOR_VERSION}_byond_linux.zip"
	wget -q "https://www.byond.com/download/build/$BYOND_MAJOR_VERSION/$zip_file"
	d_log "Unzipping new install"
	unzip -q "$zip_file"
	d_log "Deploying new install"
	mv byond "$byond_folder"
	rm "$zip_file"
fi

d_log "Finished BYOND update check"
