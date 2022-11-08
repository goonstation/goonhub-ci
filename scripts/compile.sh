#!/bin/bash
set -e
source utilities.sh
server_id="$1"
compile_log="$2"
cd "/ss13_servers/$server_id"

##
# PRECOMPILE START
##

d_log "Running pre-compile steps"

d_log "Reading existing map override"
if [ -f "mapoverride" ]; then
	map_override=$(cat mapoverride)
	d_log "Map override found: $map_override"
fi

# Set CDN group from server ID
d_log "Setting CDN group"
cdn_group="main"
[[ "$server_id" == dev* ]] && cdn_group="dev"
[[ "$server_id" == streamer* ]] && cdn_group="streamer"

# Set preload URL from CDN group
d_log "Setting preload RSC URL"
preload_rsc_url="https://cdn.goonhub.com/rsc.zip"
[ "$cdn_group" = "dev" ] && preload_rsc_url="https://cdndev.goonhub.com/rsc.zip"
[ "$cdn_group" = "streamer" ] && preload_rsc_url="https://cdnstreamer.goonhub.com/rsc.zip"

# Yeah I guess we'll just set rp mode this dumb way
d_log "Setting RP mode"
if [ "$server_id" = "main3" ] || [ "$server_id" = "main4" ] || [ "$server_id" = "main5" ]; then
	rp_mode="yes"
fi

cd repo
d_log "Building __build.dm stamps"
build_out=$(cat <<END_HEREDOC
#define LIVE_SERVER
var/global/vcs_revision = "$(git rev-parse HEAD)"
var/global/vcs_author = "$(git log -1 --pretty=format:'%an')"
#define BUILD_TIME_TIMEZONE_ALPHA "$(date +"%Z")"
#define BUILD_TIME_TIMEZONE_OFFSET $(date +"%z")
#define BUILD_TIME_FULL "$(date +"%F %T")"
#define BUILD_TIME_YEAR $(date +"%Y")
#define BUILD_TIME_MONTH $(date +"%-m")
#define BUILD_TIME_DAY $(date +"%-d")
#define BUILD_TIME_HOUR $(date +"%-H")
#define BUILD_TIME_MINUTE $(date +"%-M")
#define BUILD_TIME_SECOND $(date +"%-S")
#define BUILD_TIME_UNIX $(date +"%s")
#define PRELOAD_RSC_URL "$preload_rsc_url"
END_HEREDOC
)
cd ..

if [ -n "$map_override" ]; then
	d_log "Map override detected ($map_override), applying define"
	build_out+="
#define MAP_OVERRIDE_$map_override"
fi

if [ -n "$rp_mode" ]; then
	d_log "RP mode detected, applying define"
	build_out+="
#define RP_MODE"
fi

if [ "$cdn_group" = "streamer" ]; then
	d_log "Streamer mode detected, applying define"
	build_out+="
#define NIGHTSHADE"
fi

d_log "Finished pre-compile steps"

##
# PRECOMPILE END
##
##
# COMPILE START
##

d_log "Running compile steps"

d_log "Cleaning up build dir"
rm -r build/* >/dev/null 2>&1 || true
# Copy repo files minus hidden folders (like .git) to our build dir
d_log "Copying files from repo dir to build dir"
rsync -a --exclude=".*" repo/* build
cd build

# Stamp build-time info
d_log "Stamping __build.dm and config.txt"
echo "$build_out" > _std/__build.dm
cp -R +secret/config/* config/
cat /app/keys.txt >> config/config.txt

source buildByond.conf
BYONDDIR="/byond/$BYOND_MAJOR_VERSION.$BYOND_MINOR_VERSION"

export PATH=$BYONDDIR/bin:$PATH
export LD_LIBRARY_PATH=$BYONDDIR/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

#echo "thisProcDoesNotExist()" >> code/world.dm
d_log "Compiling"
DreamMaker goonstation.dme | tee "$compile_log" | ts "      [%Y/%m/%d %H:%M:%S]"

d_log "Copying built files to pre-deploy"
rm -r ../deploy/new/* >/dev/null 2>&1 || true
mkdir ../deploy/new/+secret
cp -r goonstation.dmb goonstation.rsc buildByond.conf assets config strings sound ../deploy/new
cp -r +secret/assets +secret/strings ../deploy/new/+secret

d_log "Finished compile steps"

##
# COMPILE END
##
