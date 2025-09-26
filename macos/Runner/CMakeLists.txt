cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX OBJCXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.mm"
  "my_application.mm"
  "my_application.h"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)

# Link macOS frameworks
find_library(COCOA_FRAMEWORK Cocoa)
find_library(FLUTTER_FRAMEWORK FlutterMacOS)
target_link_libraries(${BINARY_NAME} PRIVATE ${COCOA_FRAMEWORK})
target_link_libraries(${BINARY_NAME} PRIVATE ${FLUTTER_FRAMEWORK})

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)