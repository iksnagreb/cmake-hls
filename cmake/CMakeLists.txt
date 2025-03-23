# Add this CMake scripts directory to be discoverable as modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}")
# Typically this will be called from some higher-level CMakeLists.txt, export
# the module path back up into that scope
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} PARENT_SCOPE)

# Specify the version of the whole cmake-hls project: Needs to be set twice -
# once for the local scope and once more exported to the parent scope
set(CMAKE_HLS_VERSION_MAJOR 0)
set(CMAKE_HLS_VERSION_MAJOR ${CMAKE_HLS_VERSION_MAJOR} PARENT_SCOPE)
set(CMAKE_HLS_VERSION_MINOR 0)
set(CMAKE_HLS_VERSION_MINOR ${CMAKE_HLS_VERSION_MINOR} PARENT_SCOPE)
set(CMAKE_HLS_VERSION_PATCH 0)
set(CMAKE_HLS_VERSION_PATCH ${CMAKE_HLS_VERSION_PATCH} PARENT_SCOPE)
set(CMAKE_HLS_VERSION_TWEAK 0)
set(CMAKE_HLS_VERSION_TWEAK ${CMAKE_HLS_VERSION_TWEAK} PARENT_SCOPE)

# Composed version string following <major>[.<minor>[.<patch>[.<tweak>]]]
string(APPEND CMAKE_HLS_VERSION "${CMAKE_HLS_VERSION_MAJOR}.")
string(APPEND CMAKE_HLS_VERSION "${CMAKE_HLS_VERSION_MAJOR}.")
string(APPEND CMAKE_HLS_VERSION "${CMAKE_HLS_VERSION_PATCH}.")
string(APPEND CMAKE_HLS_VERSION "${CMAKE_HLS_VERSION_TWEAK}")
# Export the full version string into the parent scope
set(CMAKE_HLS_VERSION ${CMAKE_HLS_VERSION} PARENT_SCOPE)

# Function testing for the "Vitis HLS Integration for CMake Projects " version
# rejecting configuration if the detected version is smaller
function(cmake_hls_minimum_required)
    # A named single argument VERSION must be specified
    cmake_parse_arguments(PARSE_ARGV 0 "ARGS" "" "VERSION" "")
    # Compare the specified version to the detected version
    if(${CMAKE_HLS_VERSION} VERSION_LESS ${ARGS_VERSION})
        # Fail with error message reporting the required version
        message(FATAL_ERROR "CMake HLS ${ARGS_VERSION} or higher is required.\
            You are running version ${CMAKE_HLS_VERSION}")
    endif()
endfunction()
