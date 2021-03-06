CLI=aneth-cli.sh
INSTALLS=$(addprefix ${bindir}/,ads) $(addprefix ${libexecdir}/,aneth-cli.sh aneth-roff-style)
SYMLINKS_CLI=$(addprefix ${bindir}/,$(shell . ./${CLI} && __aneth_cli_api ${CLI} | grep -v '^import$$'))
SYMLINKS=${SYMLINKS_CLI}

include aneth-make/install.mk
-include config.mk

${libexecdir}/aneth-cli.sh: aneth-cli.sh
${SYMLINKS_CLI}: ${libexecdir}/aneth-cli.sh
${bindir}/ads: aneth-ads
${libexecdir}/aneth-roff-style: aneth-roff-style

man: ads.pdf
ads.pdf: ./aneth-ads

clean:
	$(RM) *.pdf

%.pdf:
	./aneth-ads manual --output $@ ${ADS_MANUAL_PDF_FLAGS} $(abspath $<)
.PHONY: man clean
