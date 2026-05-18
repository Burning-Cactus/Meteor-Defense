#!/bin/bash -eu

# Point this to where you installed emscripten. Optional on systems that already
# have `emcc` in the path.
EMSCRIPTEN_SDK_DIR="$HOME/repos/emsdk"
OUT_DIR="build/web"
SOURCE_DIR="src"
DEBUG=false
RUN_SERVER=false

while getopts ":hdr" opt; do
    case $opt in
        h)
            help_str="Build the project for the web and place it in ${OUT_DIR}.

            FLAGS
                -h
                    Display this menu
                -d
                    Compile in debug mode
                -r
                    Run web server after compiling
            "
            printf "$help_str"
            exit 0
            ;;
        d)
            DEBUG=true
            ;;
        r)
            RUN_SERVER=true
            ;;
    esac
done

mkdir -p $OUT_DIR

export EMSDK_QUIET=1
[[ -f "$EMSCRIPTEN_SDK_DIR/emsdk_env.sh" ]] && . "$EMSCRIPTEN_SDK_DIR/emsdk_env.sh"

# Note RAYLIB_WASM_LIB=env.o -- env.o is an internal WASM object file. You can
# see how RAYLIB_WASM_LIB is used inside <odin>/vendor/raylib/raylib.odin.
#
# The emcc call will be fed the actual raylib library file. That stuff will end
# up in env.o
#
# Note that there is a rayGUI equivalent: -define:RAYGUI_WASM_LIB=env.o
odin build $SOURCE_DIR/main_web -target:js_wasm32 -build-mode:obj -define:RAYLIB_WASM_LIB=env.o -define:RAYGUI_WASM_LIB=env.o -vet -strict-style -out:$OUT_DIR/game.wasm.o

ODIN_PATH=$(odin root)

cp $ODIN_PATH/core/sys/wasm/js/odin.js $OUT_DIR

files="$OUT_DIR/game.wasm.o ${ODIN_PATH}/vendor/raylib/wasm/libraylib.a ${ODIN_PATH}/vendor/raylib/wasm/libraygui.a"

# index_template.html contains the javascript code that calls the procedures in
# source/main_web/main_web.odin
flags="-sEXPORTED_RUNTIME_METHODS=['HEAPF32'] -sUSE_GLFW=3 -sWASM_BIGINT -sWARN_ON_UNDEFINED_SYMBOLS=0 -sASSERTIONS --shell-file ${SOURCE_DIR}/main_web/index_template.html"
if $DEBUG; then
    flags+=" -g"
fi

emcc_cmd() {
	if command -v emcc
	then emcc $@
	else $EMSCRIPTEN_SDK_DIR/upstream/emscripten/emcc $@
	fi
}

# For debugging: Add `-g` to `emcc` (gives better error callstack in chrome)
emcc_cmd -o $OUT_DIR/index.html $files $flags

rm $OUT_DIR/game.wasm.o

echo "Web build created in ${OUT_DIR}"

if $RUN_SERVER; then
    python -m http.server -d $OUT_DIR
fi
