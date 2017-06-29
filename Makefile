BLOGDOWN = .virtualenv/35/bin/run-blogdown

build: icons
	$(BLOGDOWN) build

serve: icons
	$(BLOGDOWN) serve

deploy: clean build
	rsync --delete --archive _build/ cx:/var/www

clean:
	rm -rf _build

.PHONY: serve build deploy clean

# creating icons:

# TODO: different sizes: 76, 120, 152, 180
# iOS6: 57, 72, 114, 144
# iOS7: 60, 76, 120, 152
# https://realfavicongenerator.net/blog/apple-touch-icon-the-good-the-bad-the-ugly/
# https://mathiasbynens.be/notes/touch-icons

ICONS = favicon.ico \
		apple-touch-icon-120x120-precomposed.png \
		apple-touch-icon-precomposed.png \
		apple-touch-icon.png

icons: $(ICONS)

.INTERMEDIATE: _ico32.ico _ico48.ico _ico64.ico
favicon.ico: _ico32.ico _ico48.ico _ico64.ico
	convert $^ $@

_ico%.ico: snowflake.svg
	convert $< -resize $*x$* $@

%.png: snowflake.svg
	convert $< -resize 120x120 $@
