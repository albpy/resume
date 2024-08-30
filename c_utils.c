

#include <stdio.h>
#include <dirent.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>

// Function to count the number of files in a directory
int count_files(const char *path) {
    DIR *dr = opendir(path);
    if (dr == NULL) {
        printf("Couldn't open DIR Error No: %d", errno);
        return -1;
    }

    struct dirent *de;
    int num_files = 0;

    while ((de = readdir(dr)) != NULL) {
        if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) {
            continue;
        }
        num_files++;
    }
    closedir(dr);

    int32_t num_files32 = (int32_t)num_files;
    return num_files32;
}

// Function to get the names of files in a directory
char **get_file_names(const char *path, int num_files) {
    struct dirent *de;
    DIR *dr = opendir(path);
    if (dr == NULL) {
        perror("Couldn't open dir");
        return NULL;
    }

    char **file_names = (char **)malloc(num_files * sizeof(char *));
    if (file_names == NULL) {
        perror("Memory allocation failed");
        closedir(dr);
        return NULL;
    }

    int index = 0;
    while ((de = readdir(dr)) != NULL) {
        if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) {
            continue;
        }
        file_names[index] = (char *)malloc(strlen(de->d_name) + 1);
        if (file_names[index] == NULL) {
            perror("Memory allocation failed");
            // Free previously allocated memory
            for (int i = 0; i < index; i++) {
                free(file_names[i]);
            }
            free(file_names);
            closedir(dr);
            return NULL;
        }
        strcpy(file_names[index], de->d_name);
        // printf("file_name_now: %s", file_names[index]);
        index++;
    }
    closedir(dr);
    return file_names;
}



