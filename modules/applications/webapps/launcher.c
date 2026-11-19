#include <stdio.h>
#include <unistd.h>

int main(void) {
  execl("/Applications/Nix Apps/Chromium.app/Contents/MacOS/Chromium", "Chromium",
        APP_URL, (char *)NULL);
  perror("Cannot launch the Chromium web app");
  return 1;
}
