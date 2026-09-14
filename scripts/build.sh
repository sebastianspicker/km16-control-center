#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p bin
xcrun clang -std=c11 -Wall -Wextra -Werror -O2 scripts/capture/hid-capture.c \
  -framework IOKit -framework CoreFoundation -o bin/hid-capture
bin/hid-capture --help
