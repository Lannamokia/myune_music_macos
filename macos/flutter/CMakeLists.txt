# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.13)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.
set(WRAPPER_ROOT "${EPHEMERAL_DIR}/flutter_macos")
set(FLUTTER_LIBRARY "${WRAPPER_ROOT}/FlutterMacOS.framework")

# Flutter library and tool build rules.
set(FLUTTER_TOOL_ENVIRONMENT
  "FLUTTER_ROOT=${FLUTTER_ROOT}"
  "PROJECT_DIR=${CMAKE_CURRENT_SOURCE_DIR}/../.."
  "FLUTTER_ROOT=${FLUTTER_ROOT}"
  "FLUTTER_EPHEMERAL_DIR=${EPHEMERAL_DIR}"
  "FLUTTER_TARGET_PLATFORM=darwin"
  "DART_DEFINES=${DART_DEFINES}"
  "DART_OBFUSCATION=${DART_OBFUSCATION}"
  "TRACK_WIDGET_CREATION=${TRACK_WIDGET_CREATION}"
  "TREE_SHAKE_ICONS=${TREE_SHAKE_ICONS}"
  "PACKAGE_CONFIG=${PACKAGE_CONFIG}"
)

if(NOT VERBOSE_SCRIPT_LOGGING)
  set(FLUTTER_TOOL_ENVIRONMENT ${FLUTTER_TOOL_ENVIRONMENT} "VERBOSE_SCRIPT_LOGGING=true")
endif()

set(FLUTTER_ROOT "${EPHEMERAL_DIR}/flutter_sdk" CACHE PATH "Flutter SDK")

# Most of the Flutter logic is handled in the flutter tool.
set(FLUTTER_TOOL "${FLUTTER_ROOT}/bin/flutter")
if(WIN32)
  set(FLUTTER_TOOL "${FLUTTER_TOOL}.bat")
endif()

# Build the Flutter framework and plugins.
add_custom_target(flutter_assemble ALL
  COMMAND ${CMAKE_COMMAND} -E env ${FLUTTER_TOOL_ENVIRONMENT}
    "${FLUTTER_TOOL}" assemble --output="${EPHEMERAL_DIR}"
  VERBATIM
)

# Plugin build support.
set(PLUGIN_REGISTRANT generated_plugin_registrant.cc)
list(APPEND FLUTTER_PLUGIN_LIST )

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/macos plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)