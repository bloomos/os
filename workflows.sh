#!/bin/bash

set -e

CONFIG_FILE="$1"

sh ./build-ostree.sh "$CONFIG_FILE"
