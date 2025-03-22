# The minimum CMake version with sufficient support for list transformations
cmake_minimum_required(VERSION 3.27)
# A project name for this is required to build the demo project
project(cmake-hls)

# Add the CMake scripts directory as modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Enable tests (CTest), registers all testbenches with the test target
enable_testing()

# Add the demo project from a subdirectory
add_subdirectory(demo)
