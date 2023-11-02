#!/bin/bash
set -e
source utilities.sh
server_id="$1"
compile_log="$2"
github_token="$3"
merged_prs="$4"
current_branch="$5"
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
[[ "$server_id" == main5 ]] && cdn_group="event"

# Set preload URL from CDN group
d_log "Setting preload RSC URL"
preload_rsc_url="https://cdn.goonhub.com/rsc.zip"
[ "$cdn_group" = "dev" ] && preload_rsc_url="https://cdndev.goonhub.com/rsc.zip"
[ "$cdn_group" = "event" ] && preload_rsc_url="https://cdnevent.goonhub.com/rsc.zip"
[ "$cdn_group" = "streamer" ] && preload_rsc_url="https://cdnstreamer.goonhub.com/rsc.zip"

# Yeah I guess we'll just set rp mode this dumb way
d_log "Setting RP mode"
if [ "$server_id" = "main3" ] || [ "$server_id" = "main4" ] || [ "$server_id" = "main5" ]; then
	rp_mode="yes"
fi

cd repo
d_log "Building __build.dm stamps"

local_hash=$(git rev-parse @)
local_author=$(git log --format="%an" -n 1 $local_hash)
origin_hash=$(git rev-parse $current_branch)
origin_author=$(git log --format="%an" -n 1 $origin_hash)

build_out=$(cat <<END_HEREDOC
#define LIVE_SERVER
var/global/vcs_revision = "$local_hash"
var/global/vcs_author = "$local_author"
#define VCS_REVISION "$local_hash"
#define VCS_AUTHOR "$local_author"
#define ORIGIN_REVISION "$origin_hash"
#define ORIGIN_AUTHOR "$origin_author"
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

if [ -n "$merged_prs" ]; then
	# Stamp some PR values if we have test merges active
	d_log "Testmerges detected, stamping PR IDs"
	mkdir deploy/testmerges
	split_merged_prs=$(echo $merged_prs | tr "," "\n")
	for merged_pr in $split_merged_prs; do
		curl -s \
			-H "Accept: application/vnd.github+json" \
			-H "Authorization: Bearer $github_token"\
			-H "X-GitHub-Api-Version: 2022-11-28" \
			https://api.github.com/repos/goonstation/goonstation/pulls/$merged_pr \
			-o deploy/testmerges/$merged_pr.json > /dev/null
	done
	build_out+="
#define TESTMERGE_PRS list($merged_prs)"
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

if [ ! -f "goonstation.dmb" ]; then
	d_log "Compilation failed"
	exit 1
fi

d_log "Copying built files to pre-deploy"
mkdir ../deploy/+secret
cp -r goonstation.dmb goonstation.rsc assets config strings sound ../deploy
cp -r +secret/assets +secret/strings ../deploy/+secret

d_log "Finished compile steps"

##
# COMPILE END
##
