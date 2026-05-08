#!/bin/bash -eu

OUT_DIR="build/desktop"
SOURCE_DIR="src"
mkdir -p $OUT_DIR
odin build $SOURCE_DIR/main_desktop -vet -strict-style -out:$OUT_DIR/game_desktop.bin
cp -R ./assets/ ./$OUT_DIR/
echo "Desktop build created in ${OUT_DIR}"
