#!/bin/sh

set -e

NEW_VAR_TEMPLATE="/usr/share/edk2/x64/OVMF_VARS.4m.fd"

json_tmp="$(mktemp)"

cleanup() {
    rm -f "$json_tmp"
}

trap cleanup EXIT

while getopts ":-i:-o:" opt; do
    case $opt in
	i)
	    infile="$OPTARG"
	    ;;
	o)
	    outfile="$OPTARG"
	    ;;
	*)
	    echo "Invalid argument: -${opt}" >&2
	    exit 1
    esac
done

if [ -z "$infile" ]; then
    echo "Missing required argument -i <infile>"
    exit 1
fi
if [ -z "$outfile" ]; then
    # Overwriting the file in place, so make a backup first
    timestamp="$(date "+%s")"
    backup="${infile}.${timestamp}"
    echo "Backing up $infile to $backup"
    cp -a "$infile" "$backup"
    outfile="${infile}"
else
    # Seed the outfile w/ a copy of the infile just to retain
    # the same permissions and ownership
    cp -a "$infile" "$outfile"
fi

virt-fw-vars -i "$infile" --output-json "$json_tmp"
virt-fw-vars --set-json "$json_tmp" -i "$NEW_VAR_TEMPLATE" -o "$outfile"

