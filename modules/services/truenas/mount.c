#include <CoreFoundation/CoreFoundation.h>
#include <NetFS/NetFS.h>
#include <err.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>

static CFStringRef read_credential(const char *field) {
    char *line = NULL;
    size_t capacity = 0;
    size_t prefix = strlen(field);
    ssize_t length = getline(&line, &capacity, stdin);
    CFStringRef value = NULL;

    if (length > (ssize_t)prefix + 1 && strncmp(line, field, prefix) == 0 &&
        line[length - 1] == '\n') {
        value = CFStringCreateWithBytes(NULL, (const UInt8 *)line + prefix,
                                        length - (CFIndex)prefix - 1,
                                        kCFStringEncodingUTF8, false);
    }
    free(line);
    if (!value) {
        errx(EXIT_FAILURE, "Invalid TrueNAS credential file");
    }
    return value;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        errx(EXIT_FAILURE, "Expected an SMB URL and a mount directory");
    }

    CFURLRef server = CFURLCreateWithBytes(NULL, (const UInt8 *)argv[1],
                                          strlen(argv[1]), kCFStringEncodingUTF8, NULL);
    CFURLRef directory = CFURLCreateFromFileSystemRepresentation(
        NULL, (const UInt8 *)argv[2], strlen(argv[2]), true);
    if (!server || !directory) {
        errx(EXIT_FAILURE, "Invalid TrueNAS URL or mount directory");
    }

    CFStringRef username = read_credential("username=");
    CFStringRef password = read_credential("password=");
    if (fgetc(stdin) != EOF || ferror(stdin)) {
        errx(EXIT_FAILURE, "Invalid TrueNAS credential file");
    }
    CFMutableDictionaryRef connection = CFDictionaryCreateMutable(
        NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef mount = CFDictionaryCreateMutable(
        NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    int flags = MNT_NOSUID | MNT_NODEV;
    CFNumberRef options = CFNumberCreate(NULL, kCFNumberIntType, &flags);
    CFDictionarySetValue(connection, kNAUIOptionKey, kNAUIOptionNoUI);
    CFDictionarySetValue(connection, kNetFSForceNewSessionKey, kCFBooleanTrue);
    CFDictionarySetValue(mount, kNetFSMountFlagsKey, options);
    CFDictionarySetValue(mount, kNetFSMountAtMountDirKey, kCFBooleanTrue);
    CFDictionarySetValue(mount, kNetFSForceNewSessionKey, kCFBooleanTrue);
    CFDictionarySetValue(mount, kNetFSSoftMountKey, kCFBooleanTrue);

    int result = NetFSMountURLSync(server, directory, username, password,
                                   connection, mount, NULL);
    CFRelease(options);
    CFRelease(mount);
    CFRelease(connection);
    CFRelease(password);
    CFRelease(username);
    CFRelease(directory);
    CFRelease(server);
    if (result != 0) {
        errx(EXIT_FAILURE, "TrueNAS SMB mount failed (NetFS status %d)", result);
    }
    return EXIT_SUCCESS;
}
