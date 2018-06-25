#!/usr/bin/env bash

# # REQUIREMENTS:
# * `brew install lame`
# * `brew install cdrdao`
# * `brew install bchunk`

set -o xtrace

DEVICE=/dev/rdisk1

TARGET_DIR=$PWD
TMP=/tmp/cdr-target

PROGNAME=$(basename $0)

error_exit()
{

# source: http://linuxcommand.org/lc3_wss0140.php
#	----------------------------------------------------------------
#	Function for exit due to fatal program error
#		Accepts 1 argument:
#			string containing descriptive error message
#	----------------------------------------------------------------

	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

mkdir $TMP
cd $TMP

diskutil unmount $DEVICE

cdrdao read-cd --read-raw --source-device $DEVICE data.toc
if [[ $? != "0" ]]; then error_exit "$LINENO: error extracting cd"; fi

cdrdao read-cddb data.toc

toc2cddb data.toc > data.cddb
if [[ $? != "0" ]]; then error_exit "$LINENO: error creating cddb file"; fi

toc2cue data.toc data.cue
if [[ $? != "0" ]]; then error_exit "$LINENO: error creating cue file"; fi

mkdir unprocessed
bchunk -w -r -s -v data.bin data.cue unprocessed/
if [[ $? != "0" ]]; then error_exit "$LINENO: error creating unprocessed wav files"; fi

mkdir processed
toc2mp3 -d processed -c -v 2 -b 320 data.toc
if [[ $? != "0" ]]; then error_exit "$LINENO: error creating compressed mp3 files"; fi

DISCID=`cat data.cddb | grep DISCID | cut -d "=" -f2`
DTITLE=`cat data.cddb | grep DTITLE | cut -d "=" -f2`

NAME=$DISCID
if [[ ! -z "${DTITLE// }" ]]; then
  NAME=$NAME\ -\ $DTITLE
fi

cd $TARGET_DIR
mv $TMP "./${NAME/\//-}"
if [[ $? != "0" ]]; then error_exit "$LINENO: error moving to target location"; fi

diskutil eject $DEVICE
if [[ $? != "0" ]]; then error_exit "$LINENO: error ejecting CD"; fi
