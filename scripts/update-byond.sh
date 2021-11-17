#!/bin/bash
set -e
server_id="$1"

cd "/ss13_servers/$server_id/repo"
source buildByond.conf
byond_folder="$BYOND_MAJOR_VERSION.$BYOND_MINOR_VERSION"

cd /byond
if [ ! -d "$byond_folder" ]; then
	zip_file="${BYOND_MAJOR_VERSION}.${BYOND_MINOR_VERSION}_byond_linux.zip"
	wget -q "https://www.byond.com/download/build/$BYOND_MAJOR_VERSION/$zip_file"
	unzip -q "$zip_file"
	mv byond "$byond_folder"
	rm "$zip_file"
fi
