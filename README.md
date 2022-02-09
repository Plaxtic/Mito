## Mito(sis)

Experiments with self replicating programs

### SOME OF THESE PROGRAMS ARE DANGEROUS

deleto will deleto the filename you pass it (no matter the owner) from 
this and all higher directories  
all the others will copy themselves into all higher directories

to try them out:
```
./build
cp bin/mito .
mkdir -p 1/{1..2}/{1..3}/{1..4}/{1..5}
./mito
tree
```

