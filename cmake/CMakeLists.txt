# Add this CMake scripts directory to be discoverable as modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}")
# Typically this will be called from some higher-level CMakeLists.txt, export
# the module path back up into that scope
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} PARENT_SCOPE)
