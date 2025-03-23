# Vitis HLS Integration for CMake Projects
The CMake scripts are self-contained, i.e., this integration could be installed
by simply copying the scripts from the [cmake](cmake) subdirectory into your
existing CMake project. However, it is recommended to integrate this as a
dependency via [CMake FetchContent](https://cmake.org/cmake/help/latest/module/FetchContent.html):
```cmake
# Make the FetchContent module available
include(FetchContent)

# Declare the Vitis HLS Integration as dependency to be populated via
# FetchContent pulling from GitHub
FetchContent_Declare(
    # Can be chosen arbitrarily, but recommended to stick with the project name
    cmake-hls
    # URL to the project GitHub repository
    GIT_REPOSITORY  https://github.com/iksnagreb/cmake-hls.git
    # Select the git tag to be pulled - recommended to pin a commit hash
    GIT_TAG         66e9c9f14d022e1a65582957cd56604a17cf1556
    # Only include the CMake scripts/modules, without this the demo project will
    # be registered as build targets as well
    SOURCE_SUBDIR   cmake
)

# Declare more dependencies...
# ...

# Make the declared dependencies available
FetchContent_MakeAvailable(cmake-hls ...)
```
