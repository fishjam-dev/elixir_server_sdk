#!/bin/bash

# Terminate on errors
set -e


printf "Synchronising submodules... "
git submodule sync --recursive >> /dev/null
git submodule update --recursive --remote --init >> /dev/null
printf "DONE\n\n"

file="./protos/jellyfish/server_notifications.proto"
printf "Compiling: file $file\n"
protoc --elixir_out=./lib/ $file
printf "DONE\n"

mix format "lib/protos/**/*.ex"