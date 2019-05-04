#!/bin/bash

# this great idea is from https://stackoverflow.com/a/35889620/3821794

#File: tree-md

tree=$(tree -f --dirsfirst --noreport --charset ascii $1 |
       sed -e 's/| \+/  /g' -e 's/[|`]-\+/ */g' -e 's:\(* \)\(\(.*/\)\([^/]\+\)\):\1[\4](\2):g')

printf "# Project tree\n\n${tree}"