#!/bin/sh

nvim --headless -i NONE -n -u spec/minimal_init.lua -l "$@"
exit_code=$?

exit $exit_code
