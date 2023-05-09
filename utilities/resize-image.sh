#! /usr/bin/env bash

image=$1
# Copy the snap-specific field to a general field so it's preserved on resize
exiftool -"Comment<Snap_SRC" "$image"
# resize with image magic
convert "$image" -resize 150% "$image"
# imagemagic saves Comments to a special compressed text field
# Re-use exiftool to copy the compressed comment to an uncompressed one.
exiftool -"Comment<Comment" "$image"
