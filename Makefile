ODINFLAGS := -vet -strict-style
CONSIDER_CONTENTS := assets src

default: build/desktop/game

# lil hack to make Make consider the contents of directory prereqs
contents = $(shell find $1 -type f)
.SECONDEXPANSION:
${CONSIDER_CONTENTS}: $$(call contents,$$@)
	touch $@

%/assets: assets
	mkdir -p $@
	cp -R --no-target-directory $< $@

build/desktop/game: src build/desktop/assets
	odin build $</main_desktop ${ODINFLAGS} -out:$@

build/web:
	./build_web.sh

build/web.zip: build/web
	zip -r --junk-paths $@ $</*

run: build/desktop/game
	$<

serve: build/web
	./build_web.sh -r

clean:
	rm -rf build/

.PHONY: web-debug run serve clean
