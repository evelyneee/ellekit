
#ifndef inject_h
#define inject_h

#include <ctype.h>
#include <mach/mach_types.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <unistd.h>
#include <spawn.h>
#include <sys/wait.h>

kern_return_t inject_to_task(mach_port_t task, const char *argument);
kern_return_t get_thread_port_for_task(mach_port_t task, mach_port_t *thread);

// MARK: - PAC

extern void* sign_pointer(void* ptr);
extern void* strip_pointer(void* ptr);
extern void* sign_pc(void* ptr);

extern char** buildstr(char *const argv[restrict]);

#ifndef HEXDUMP_COLS
#define HEXDUMP_COLS 16
#endif

extern char **environ;

void run_cmd(const char *cmd)
{
    pid_t pid;
    char *argv[] = {"sh", "-c", cmd, NULL};
    int status;
    printf("Run command: %s\n", cmd);
    status = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
    if (status == 0) {
        printf("Child pid: %i\n", pid);
        do {
          if (waitpid(pid, &status, 0) != -1) {
            printf("Child status %d\n", WEXITSTATUS(status));
          } else {
            perror("waitpid");
            exit(1);
          }
        } while (!WIFEXITED(status) && !WIFSIGNALED(status));
    } else {
        printf("posix_spawn: %s\n", strerror(status));
    }
}
 
extern void posix_spawn_patch(pid_t *restrict pid, const char *restrict path,
                              const posix_spawn_file_actions_t *file_actions,
                              const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
                              char * envp[restrict]);

extern void* patch_addr(void);

char **const uwu(void) {
    char *const arr[] = { "DYLD_INSERT=\"a\"", "DYLD_INSERT=\"b\"" };
    return arr;
}

void hexdump(void *mem, unsigned int len)
{
        unsigned int i, j;
        
        for(i = 0; i < len + ((len % HEXDUMP_COLS) ? (HEXDUMP_COLS - len % HEXDUMP_COLS) : 0); i++)
        {
                /* print offset */
                if(i % HEXDUMP_COLS == 0)
                {
                        printf("0x%06x: ", i);
                }
 
                /* print hex data */
                if(i < len)
                {
                        printf("%02x ", 0xFF & ((char*)mem)[i]);
                }
                else /* end of block, just aligning for ASCII dump */
                {
                        printf("   ");
                }
                
                /* print ASCII dump */
                if(i % HEXDUMP_COLS == (HEXDUMP_COLS - 1))
                {
                        for(j = i - (HEXDUMP_COLS - 1); j <= i; j++)
                        {
                                if(j >= len) /* end of block, not really printing */
                                {
                                        putchar(' ');
                                }
                                else if(isprint(((char*)mem)[j])) /* printable char */
                                {
                                        putchar(0xFF & ((char*)mem)[j]);
                                }
                                else /* other char */
                                {
                                        putchar('.');
                                }
                        }
                        putchar('\n');
                }
        }
}
 
#ifdef HEXDUMP_TEST
int main(int argc, char *argv[])
{
        hexdump(argv[0], 20);
 
        return 0;
}
#endif

#endif /* inject_h */
