.PHONY: build serve clean

build:
	dune exec bin/site.exe

serve:
	dune exec bin/site.exe -- serve 8000

clean:
	rm -rf _site .yocaml-cache
