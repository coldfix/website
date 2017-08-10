BLOGDOWN = .virtualenv/35/bin/run-blogdown

build: icons
	$(BLOGDOWN) build

serve: icons
	$(BLOGDOWN) serve

deploy: build
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

ICONS = _build/favicon.ico \
		_build/apple-touch-icon-120x120-precomposed.png \
		_build/apple-touch-icon-precomposed.png \
		_build/apple-touch-icon.png

icons: $(ICONS)

.INTERMEDIATE:      _build/_ico32.ico _build/_ico48.ico _build/_ico64.ico
_build/favicon.ico: _build/_ico32.ico _build/_ico48.ico _build/_ico64.ico
	convert $^ $@

_build/_ico%.ico: snowflake.svg
	convert $< -resize $*x$* $@

_build/%.png: snowflake.svg
	convert $< -resize 120x120 $@
