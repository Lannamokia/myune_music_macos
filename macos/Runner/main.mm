include <Cocoa/Cocoa.h>
#include <FlutterMacOS/FlutterMacOS.h>

#include "my_application.h"

int main(int argc, const char * argv[]) {
  [NSApplication sharedApplication];
  return NSApplicationMain(argc, argv);
}