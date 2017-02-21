all: postfix-dovecot.svg

%.pdf: %.tex
	pdflatex $<

%.svg: %.pdf
	pdf2svg $< $@
