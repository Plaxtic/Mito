#!/bin/sh -e

## build nasm source
for x in aito/*o.asm
do
    BASE=`basename "$x" .asm`

    nasm -f elf64 "$x"
    ld "aito/$BASE.o" -o "bin/$BASE" && echo $BASE
    rm "aito/$BASE.o"
done

## build C source
for c in cito/*.c
do
    BASE=`basename "$c" .c`
    gcc -o "bin/$BASE" $c && echo $BASE
done

## build 32 bit sito
nasm aito/sito32.asm -o bin/sito32
chmod +x bin/sito32
echo sito32
