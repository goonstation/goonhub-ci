#!/bin/bash
set -e
cd "$(dirname "$0")"
server_id=''
skip_cdn=''
compile_log=''
github_token=''
merged_prs=''
current_branch=''

print_usage() {
	printf "You did a bad"
}

while getopts 's:rb:c:p:n:' flag; do
  case "${flag}" in
    s) server_id="${OPTARG}" ;;
    r) skip_cdn='true' ;;
    b) compile_log="${OPTARG}" ;;
    c) github_token="${OPTARG}" ;;
		p) merged_prs="${OPTARG}" ;;
		n) current_branch="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

if [ ! "$server_id" ]; then
	echo "Missing server ID" >&2
	exit 1
fi
if [ ! "$compile_log" ]; then
	echo "Missing compile logfile" >&2
	exit 1
fi

# Clean up deploy directory ahead of time
rm -r /ss13_servers/$server_id/deploy/* >/dev/null 2>&1 || true

/bin/bash update-byond.sh "$server_id"
/bin/bash compile.sh "$server_id" "$compile_log" "$github_token" "$merged_prs" "$current_branch"
#/bin/bash update-rust-g.sh "$server_id"
if [ ! "$skip_cdn" ]; then
	/bin/bash update-cdn.sh "$server_id"
fi
/bin/bash deploy.sh "$server_id"
