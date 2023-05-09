#! /usr/bin/env bash

image=$1
exiftool -"Comment<Snap_SRC" "$image"
convert "$image" -resize 150% "$image"
exiftool -"Comment<Comment" "$image"
