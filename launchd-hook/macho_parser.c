//
//  macho_parser.c
//  pspawn
//
//  Created by charlotte on 2022-12-16.
//

#include "macho_parser.h"

#include <stdio.h>
#include <mach-o/loader.h>
#include <stdlib.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>

char** get_segment_bundles(const char* macho_path) {
    // Open the Mach-O file
    FILE *fp = fopen(macho_path, "rb");
    if (!fp) {
        puts("failed to open file");
        return NULL;
    }
    
    // Read the Mach-O header
    struct mach_header_64 mh;
    fread(&mh, sizeof(mh), 1, fp);
    
    // Allocate an array to hold the names of the files in the LC_SEGMENT_64 load commands
    char** filenames = malloc(sizeof(char*) * mh.ncmds);
    int filename_count = 0;
    
    printf("%d\n", mh.ncmds);
    
    // Iterate over the load commands
    for (int i = 0; i < mh.ncmds; i++) {
        // Read the load command
        struct load_command lc;
        fread(&lc, sizeof(lc), 1, fp);
        
        // Check the type of the load command
        if (lc.cmd == LC_SEGMENT_64) {
            // Extract the file name from the LC_SEGMENT_64 load command
            struct segment_command_64 sc;
            fread(&sc, sizeof(sc), 1, fp);
            char* segname = strdup(sc.segname);
            printf("segment: %s\n", segname);
            CFURLRef bin_path = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFStringCreateWithCString(kCFAllocatorDefault, segname, kCFStringEncodingASCII), kCFURLPOSIXPathStyle, 0);
            if (!bin_path) continue;
            CFURLRef path = CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorDefault, bin_path);
            if (!path) continue;
            CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, path);
            if (!bundle) continue;
            CFStringRef cfid = CFBundleGetIdentifier(bundle);
            const char* id = CFStringGetCStringPtr(cfid, kCFStringEncodingASCII);
            filenames[filename_count] = (char*)id;
            filename_count++;
        } else {
            // Skip other types of load commands
            fseek(fp, lc.cmdsize - sizeof(lc), SEEK_CUR);
        }
    }
    
    // Resize the array to the actual number of filenames
    filenames = realloc(filenames, sizeof(char*) * filename_count);
    
    // Close the Mach-O file
    fclose(fp);
    return filenames;
}
