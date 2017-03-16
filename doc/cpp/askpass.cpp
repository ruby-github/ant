#include <string.h>
#include <stdlib.h>

#include <unistd.h>

#include <iostream>
#include <fstream>
#include <string>

using namespace std;

int main(int argc, char *argv[]) {
  if (argc > 1) {
    cerr << argv[1] << endl;

    string home = getenv("HOME");

    if (!home.empty()) {
      string filename = home + "/.askpass";

      for (int i = 0; i < 10; i++) {
        ifstream fin(filename.c_str());

        if (fin) {
          char buffer[4096];

          fin.read(buffer, 4096);
          fin.close();

          cout << buffer << endl;

          break;
        }

        sleep(1);
      }

      remove(filename.c_str());
    }
  }

  return 0;
}