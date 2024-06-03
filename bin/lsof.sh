#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2021 Splunk, Inc. <sales@splunk.com>
# SPDX-License-Identifier: Apache-2.0

# shellcheck disable=SC1091
. "$(dirname "$0")"/common.sh

assertHaveCommand lsof
CMD='lsof -nPs +c 0'

# shellcheck disable=SC2016
PRINTF='{
    id = 1
    # Split positions into an array
    split(positions, positions_array, " ")
    split(headers, headers_array, " ")
    for (i = 1; i <= length(positions_array); i++) {
        if (i == length(positions_array)) {
            field = substr($0, positions_array[i])
        } else {
            field = substr($0, positions_array[i] - 1, 1 + headers_array[i])
        }
        if (field ~ /^ *$/) {
            id--
            field = "?"
        }
        else {
            field = $id
        }
        id = id+1
        printf "%20s ", field
    }
    printf "\n"
}'
# shellcheck disable=SC2016
FILTER='/Permission denied|NOFD|unknown/ {next}'

if [[ "$KERNEL" = "Linux" ]] || [[ "$KERNEL" = "HP-UX" ]] || [[ "$KERNEL" = "Darwin" ]] || [[ "$KERNEL" = "FreeBSD" ]] ; then
	if [ "$KERNEL" = "Darwin" ] ; then
		# shellcheck disable=SC2016
		FILTER='/KQUEUE|PIPE|PSXSEM/ {next}'
	elif [ "$KERNEL" = "FreeBSD" ] ; then
		if [[ $KERNEL_RELEASE =~ 11.* ]] || [[ $KERNEL_RELEASE =~ 12.* ]] || [[ $KERNEL_RELEASE =~ 13.* ]]; then
			# empty condition to allow the execution of script as is
			echo > /dev/null
		else
			failUnsupportedScript
		fi
	fi
	# shellcheck disable=SC2016
	POSITIONS=$(lsof -nPs +c 0 | awk 'NR == 1 { for (i = 1; i <= NF; i++) printf "%s ", index($0, $i); exit }')
	# shellcheck disable=SC2016
	HEADERS=$(lsof -nPs +c 0 | awk 'NR == 1 { for (i = 1; i <= NF; i++) printf "%s ", length($i); exit }')
else
	failUnsupportedScript
fi

assertHaveCommand "$CMD"
# shellcheck disable=SC2094
$CMD 2>"$TEE_DEST" | tee "$TEE_DEST" | awk -v positions="$POSITIONS" -v headers="$HEADERS" "$FILTER $PRINTF"
echo "Cmd = [$CMD 2>$TEE_DEST];  | awk -v positions=\"$positions\" -v headers=\"$headers\" \"$FILTER $PRINTF\"" >> "$TEE_DEST"
