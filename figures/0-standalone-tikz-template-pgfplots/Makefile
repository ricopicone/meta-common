.PHONY: all
	
tex = $(wildcard *.tex)
pdf = $(tex:.tex=.pdf)

all: $(pdf)
	
%.pdf: %.tex
	latexmk -lualatex -shell-escape $<
