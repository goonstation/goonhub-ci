#!/bin/bash
set -e
server_id="$1"
compile_log="$2"
cd "/ss13_servers/$server_id"

##
# PRECOMPILE START
##

if [ -f "game/data/mapoverride" ]; then
	map_override=$(cat game/data/mapoverride)
fi

# Set CDN group from server ID
cdn_group="main"
[[ "$server_id" == dev* ]] && cdn_group="dev"
[[ "$server_id" == streamer* ]] && cdn_group="streamer"

# Set preload URL from CDN group
preload_rsc_url="https://cdn.goonhub.com/rsc.zip"
[ "$cdn_group" = "dev" ] && preload_rsc_url="https://cdndev.goonhub.com/rsc.zip"
[ "$cdn_group" = "streamer" ] && preload_rsc_url="https://cdnstreamer.goonhub.com/rsc.zip"

# Yeah I guess we'll just set rp mode this dumb way
if [ "$server_id" = "main3" ] || [ "$server_id" = "main4" ]; then
	rp_mode="yes"
fi

cd repo
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
	echo "Map override detected, applying define..."
	build_out+="
#define MAP_OVERRIDE_$map_override"
fi

if [ -n "$rp_mode" ]; then
	echo "RP mode detected, applying define..."
	build_out+="
#define RP_MODE"
fi

##
# PRECOMPILE END
##
##
# COMPILE START
##

rm -r build/* >/dev/null 2>&1 || true
# Copy repo files minus hidden folders (like .git) to our build dir
rsync -a --exclude=".*" repo/* build
cd build

source buildByond.conf
BYONDDIR="/byond/$BYOND_MAJOR_VERSION.$BYOND_MINOR_VERSION"
export PATH=$BYONDDIR/bin:$PATH
export LD_LIBRARY_PATH=$BYONDDIR/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Stamp build-time info
echo "$build_out" > _std/__build.dm
cp -R +secret/config/* config/
cat /app/keys.txt >> config/config.txt

#echo "thisProcDoesNotExist()" >> code/world.dm
DreamMaker goonstation.dme > "$compile_log"

# Make and deploy rsc.zip
echo "Building RSC zip..."
zip -9 rsc.zip goonstation.rsc
echo "Deploying RSC zip..."
mv rsc.zip "/goonhub_cdn/public/$cdn_group"

cd ..
rsync -a --exclude=data --exclude=adventure build/* game/update

##
# COMPILE END
##
