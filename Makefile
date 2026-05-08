.PHONY: web web-debug run serve clean

ODINFLAGS := -vet -strict-style


%/assets:
	mkdir -p $@
	cp -R --no-target-directory assets $@

build/desktop/game: src build/desktop/assets
	odin build $</main_desktop ${ODINFLAGS} -out:$@

web:
	./build_web.sh

web-debug:
	./build_web.sh -d

run: build/desktop/game
	$<

serve: web
	./build_web.sh -r

clean:
	rm -rf build/
