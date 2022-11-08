#!/bin/bash
set -e
shopt -s extglob
source utilities.sh
server_id="$1"
ci_api_key="$2"
change_list="changelist.txt"
cd "/ss13_servers/$server_id/deploy"

d_log "Running deployment"

[ -f "$change_list" ] && > "$change_list"

if [ -d "new/cdn" ]; then
	d_log "CDN changed"
	rm -r current/cdn >/dev/null 2>&1 || true
	mv new/cdn current
	echo "cdn" >> "$change_list"
fi

assets_diff=$(diff -qr -x *.rsc -x *.dmb -x cdn current new || true)
if [ -n "$assets_diff" ]; then
	d_log "Assets changed"
	rm -r current/!(goonstation.rsc|goonstation.dmb|cdn) >/dev/null 2>&1 || true
	mv new/!(goonstation.rsc|goonstation.dmb|cdn) current
	ls --ignore=goonstation.rsc --ignore=goonstation.dmb --ignore=cdn current -1 >> "$change_list"
fi

rsc_diff=$(cmp -s current/goonstation.rsc new/goonstation.rsc || echo "diff")
if [ -n "$rsc_diff" ]; then
	d_log "Rsc changed"
	mv new/goonstation.rsc current
	echo "goonstation.rsc" >> "$change_list"
fi

dmb_diff=$(cmp -s current/goonstation.dmb new/goonstation.dmb || echo "diff")
if [ -n "$dmb_diff" ]; then
	d_log "Dmb changed"
	mv new/goonstation.dmb current
	echo "goonstation.dmb" >> "$change_list"
fi

if [ -s "$change_list" ]; then
	d_log "Building deployment package"
	cd current
	tar -zcf ../deploy.tar.gz -T "../$change_list"
	cd ..

	d_log "Uploading deployment package"
	curl -s -S --location --request POST 'https://ci.goonhub.com/update-game' \
		--header "Api-Key: $ci_api_key" \
		--form "server=\"$server_id\"" \
		--form 'update=@"deploy.tar.gz"'
	# TODO: develop local fallback to avoid post request
fi

d_log "Finished deployment"
