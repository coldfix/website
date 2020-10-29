BLOGDOWN = pipenv run run-blogdown

build: icons
	$(BLOGDOWN) build

serve: icons
	$(BLOGDOWN) serve

deploy: build
	rsync --delete --archive _build/ cx:/var/www

clean:
	rm -rf _build

draft:
	@./bin/draft

publish:
	@./bin/publish

.PHONY: serve build deploy clean draft publish

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
	@mkdir -p _build
	convert -background none $< -resize $*x$* $@

_build/%.png: snowflake.svg
	@mkdir -p _build
	convert -background none $< -resize 120x120 $@
