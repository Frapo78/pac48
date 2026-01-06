#!/bin/bash
set -e

sjasmplus src/main.asm build/pac48.bin
bin2tap.py -o 32768 -s 32768 -c 32767 build/pac48.bin build/pac48.tap
