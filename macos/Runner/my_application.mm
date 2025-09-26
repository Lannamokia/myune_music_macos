#import "my_application.h"

#import <FlutterMacOS/FlutterMacOS.h>

#include "flutter/generated_plugin_registrant.h"

@interface MyApplication ()
@property (nonatomic, strong) FlutterViewController *flutterViewController;
@end

@implementation MyApplication

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // Create the main window
  NSRect frame = NSMakeRect(0, 0, 1280, 720);
  NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                 styleMask:(NSWindowStyleMaskTitled |
                                                           NSWindowStyleMaskClosable |
                                                           NSWindowStyleMaskMiniaturizable |
                                                           NSWindowStyleMaskResizable)
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
  
  [window setTitle:@"Myune Music"];
  [window center];
  
  // Create Flutter view controller
  FlutterDartProject *project = [[FlutterDartProject alloc] init];
  self.flutterViewController = [[FlutterViewController alloc] initWithProject:project];
  
  // Register plugins
  RegisterGeneratedPlugins(self.flutterViewController);
  
  // Set the Flutter view as the window's content view
  [window setContentViewController:self.flutterViewController];
  [window makeKeyAndOrderFront:self];
  
  [self setActivationPolicy:NSApplicationActivationPolicyRegular];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return YES;
}

@end