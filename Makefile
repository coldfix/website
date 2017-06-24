BLOGDOWN = .virtualenv/35/bin/run-blogdown

build: icons
	$(BLOGDOWN) build

serve: icons
	$(BLOGDOWN) serve

icons: $(ICONS)
	./makeico.sh

deploy: clean build
	rsync --delete --archive _build/ cx:/var/www

clean:
	rm -rf _build

.PHONY: serve build deploy clean
