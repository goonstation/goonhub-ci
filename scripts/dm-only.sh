#!/bin/bash

BYONDDIR="/byond/514.1566"
export PATH=$BYONDDIR/bin:$PATH
export LD_LIBRARY_PATH=$BYONDDIR/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

DreamMaker goonstation.dme
