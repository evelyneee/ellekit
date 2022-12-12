
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

extern char ***_NSGetEnviron(void);

// MARK: - PAC

extern void* sign_pointer(void* ptr);
extern void* strip_pointer(void* ptr);
extern void* sign_pc(void* ptr);

extern char** buildstr(char *const argv[restrict]);

#ifndef HEXDUMP_COLS
#define HEXDUMP_COLS 16
#endif

extern char **environ;

char **const uwu(void) {
    char *const arr[] = { "DYLD_INSERT=\"a\"", "DYLD_INSERT=\"b\"" };
    return arr;
}

void run_cmd(const char *cmd)
{
    pid_t pid;
    char *argv[] = { cmd, NULL };
    int status;
    puts("running command");
    status = posix_spawn(&pid, cmd, NULL, NULL, argv, NULL);
    if (status == 0) {
        printf("child pid is %i\n", pid);
    } else {
        printf("posix_spawn: %s\n", strerror(status));
    }
}
 
extern void posix_spawn_patch(pid_t *restrict pid, const char *restrict path,
                              const posix_spawn_file_actions_t *file_actions,
                              const posix_spawnattr_t *restrict attrp, char *const argv[restrict],
                              char * envp[restrict]);

extern void* patch_addr(void);

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
