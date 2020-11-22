#!/bin/bash

set -e

CONFIG_FILE="$1"

./build-ostree.sh "$CONFIG_FILE"
