Any TeX engine can be used to work with this template, (i.e., LaTeX/PDFLaTeX/XeLaTeX, etc.) 

Two types of "Notes" available in the template 
		1) page footnote and  - use standard tag "\footnote"
		2) chapter/book end notes - use the tag "\endnote{…}" and "\theendnotes" to print the endnotes

Use "biber.exe" instead of "bibtex.exe" to generate the reference entries in a better way

Two options to handle the math heads like, Theorem, Lemma, etc. 
	\documentclass[thmnumcontwithchapter] - which produces the output as Theorem 1.1 and Lemma 1.1, etc.
	\documentclass[thmnumcont] - which produces the output as Theorem 1 and Lemma 2, etc.
Default is Theorem 1, Lemma 1, etc.

Trim size 6 x 9 fixed as default in the template, it can be changed as mentioned below:
	\documentclass[7x10]{NewMath_MIT} --- If the trim size as 7x10 
	\documentclass[8x10]{NewMath_MIT} --- If the Trim size as 8x10

We have fixed the first level heading as "Headline Style" with Title case. \Addlcwords {} can be used to ignore the stop words (i.e. "the", "of", "into", "for", "that", etc. 
e.g. \Addlcwords{the of into that for}
