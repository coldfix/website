#! /usr/bin/env zsh

sizes=(32 48 64)

for size in $sizes; do
    convert snowflake.svg -resize ${size}x${size} _ico${size}.ico
done

convert _ico*.ico favicon.ico
rm _ico*.ico

# TODO: different sizes: 76, 120, 152, 180
# iOS6: 57, 72, 114, 144
# iOS7: 60, 76, 120, 152
# https://realfavicongenerator.net/blog/apple-touch-icon-the-good-the-bad-the-ugly/
# https://mathiasbynens.be/notes/touch-icons
convert snowflake.svg -resize 120x120 apple-touch-icon-120x120-precomposed.png
convert snowflake.svg -resize 120x120 apple-touch-icon-precomposed.png
