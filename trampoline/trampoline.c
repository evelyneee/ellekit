#if defined(__arm64__) || defined(__arm64e__) || defined(__x86_64__)
#else

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

#define BIN_PATH "/Applications/CrossOver.app/Contents/MacOS/CrossOver_original"
#define DYLIB_PATH "/Applications/CrossOver.app/Contents/MacOS/hook.dylib"

int main(void) {
  printf("[Trampoline] Hello world!\n");
  int ret = setenv("DYLD_INSERT_LIBRARIES", DYLIB_PATH, 1);
  if (ret == 0) {
    printf("[Trampoline] Env setting success\n");
  }
  char* arg[] = {BIN_PATH, NULL};
  int executed = execl(BIN_PATH, BIN_PATH);
  if (executed != 0) {
    printf("[Trampoline] Failed to call, resign CrossOver_original\n");
  }
  printf("[Trampoline] Called binary, goodbye\n");
  return 0;
}
#endif
