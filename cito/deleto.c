/*
 * =====================================================================================
 *
 *       Filename    :  Deleto
 *       Description :  recursively deletes <filname> ! DANGER !
 *       Compiler    :  gcc
 *
 * =====================================================================================
 */


#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>

int main (int argc, char *const *argv) {
    struct dirent *dr;

    if (argc < 2) {
        printf("Usage: %s <file to delete>\n", argv[0]);
        return 1;
    }

    DIR *d = opendir(".");
    if (d == NULL) {
        perror("opendir");
        return 1;
    }

    while ((dr = readdir(d)) != NULL) {
        if (!strcmp(dr->d_name, argv[1])) {
            if (remove(argv[1]) < 0) {
                perror(argv[1]);
            }
            else {
                char path[PATH_MAX] = {0};
                getcwd(path, PATH_MAX);
                printf("%s\r", path);
                fflush(stdout);
            }
        }

        if (dr->d_type == DT_DIR 
                && strcmp(dr->d_name, ".") 
                && strcmp(dr->d_name, "..")) {

            chdir(dr->d_name);
            main(argc, argv);       // recursion!
            chdir("..");
        }
    }
    closedir(d);
    return 0;
}

