#!/bin/bash

# Terminate on errors
set -e


printf "Synchronising submodules... "
git submodule sync --recursive >> /dev/null
git submodule update --recursive --remote --init >> /dev/null
printf "DONE\n\n"

file=$(find protos/jellyfish -name "server_notifications.proto")
protoc --elixir_out=./lib/ $file

mix format "lib/protos/**/*.ex"