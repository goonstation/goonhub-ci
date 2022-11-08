#!/bin/bash
set -e
server_id="$1"
branch="$2"

cd /ss13_servers
#mkdir "$server_id"
cd "$server_id"
#mkdir repo build deploy deploy/current deploy/new
mkdir deploy/current deploy/new

cd repo
git clone --recurse-submodules -b "$branch" https://github.com/goonstation/goonstation .
