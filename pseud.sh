#!/bin/sh

## check args
if [ "$1" == "" ]
then
    printf "Usage: %s <asm>\n" "$0"
    exit 1
fi

## use bat to prettify if installed
if command -v bat &> /dev/null
then
    grep ";;" "$1" | cut -d ";" -f 3 | bat -p -l c
else
    grep ";;" "$1" | cut -d ";" -f 3
fi
