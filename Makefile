BLOGDOWN = .virtualenv/27/bin/run-blogdown

build:
	$(BLOGDOWN) build

serve:
	$(BLOGDOWN) serve

deploy: clean build
	rsync --delete --archive _build/ cx:/var/www

clean:
	rm -rf _build

.PHONY: serve build deploy clean
