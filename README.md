## Mito(sis)

Experiments with self replicating programs

### SOME OF THESE PROGRAMS ARE DANGEROUS

deleto will deleto the filename you pass it (no matter the owner) from 
this and all higher directories  
All the others will copy themselves into all higher directories

Requires nasm

To try them out:
```
./build
cp bin/zito .
mkdir -p 1/{1..2}/{1..3}/{1..4}/{1..5}
./zito
tree
```
x86 source is in aito, C source in cito

pseud.sh prints out my pseudo-C annotations of the assembly source
