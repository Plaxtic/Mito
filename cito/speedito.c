/*
 * =====================================================================================
 *
 *       Filename    :  speedito.c
 *       Description :  recursively copies self into all higher directories
 *       Compiler    :  gcc
 *
 * =====================================================================================
 */


#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <sys/sendfile.h>
#include <sys/mman.h>
#include <sys/stat.h>

int traverse(char*, uint8_t*, size_t);

int main (int argc, char *const *argv) {

    int fd = open(argv[0], O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    struct stat fst;
    if (fstat(fd, &fst) != 0) {
        perror("lstat");
        return 1;
    }
    size_t siz = fst.st_size;

    uint8_t *map = mmap(NULL, siz, PROT_READ, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED) {
        perror("mmap");
        return 1;
    }

    traverse(argv[0]+2, map, siz);

    close(fd);
    munmap(map, siz);
}


int traverse(char *path, uint8_t *map, size_t siz) {

    DIR *d = opendir(".");
    if (d == NULL) {
        perror("opendir");
        return -1;
    }

    struct dirent *dr;
    while ((dr = readdir(d)) != NULL) {
        if (dr->d_type == DT_DIR 
                && strcmp(dr->d_name, ".") 
                && strcmp(dr->d_name, "..")) {
            chdir(dr->d_name);

            struct stat lst;
            if (lstat(path, &lst) != 0) {
                int fd = open(path, O_CREAT | O_WRONLY, 0777);

                if (fd < 0) return -1;

                write(fd, map, siz);
                close(fd);
            }
            traverse(path, map, siz);
            chdir("..");
        }
    }
    closedir(d);
    return 0;
}

