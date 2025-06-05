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
    GIT_TAG         ed8c5b963a544ff4ad40bbf8ac8c86c44a94924c
    # Only include the CMake scripts/modules, without this the demo project will
    # be registered as build targets as well
    SOURCE_SUBDIR   cmake
)

# Declare more dependencies...
# ...

# Make the declared dependencies available
FetchContent_MakeAvailable(cmake-hls ...)
```

## Simple Usage Example
Once made available as a CMake dependency, simply `include(vitis)` and add Vitis
IP or kernel targets registering design and simulation sources. For details on
available configuration options please refer to the source code documentation
within the [vitis](cmake/vitis.cmake) CMake module and the
[Vitis HLS User Guide](https://docs.amd.com/r/en-US/ug1399-vitis-hls), in
particular sections on the `v++` and `vitis-run` commands.
```cmake
# Needs the Vitis HLS tools and custom targets
include(vitis)

# Set a minimum version of the Vitis tools required to continue from here...
vitis_minimum_required(VERSION 2023.2)

# This demo project builds a simple adder IP with Vitis HLS also adding C++
# Simulation and C++/RTL Co-Simulation. Targets the Zynq UltraScale+.
add_vitis_ip(
    # Name of the interface target, default name of the top-level function
    adder
    # Design C++ sources to be synthesize
    SOURCES adder.cpp
    # C++ Sources only used by the simulation
    TESTBENCH adder_tb.cpp
    # Zynq UltraScale+ target
    PART zynquplus
)
```

## Experimental SYCL for Vitis Integration
The [sycl](cmake/sycl.cmake) CMake module provides experimental integration of
[SYCL for Vitis](https://github.com/triSYCL/sycl) which can be used for
experimenting with a slightly more modern Clang/LLVM frontend compiler as a
design entry. This could offer up to C++23(?) support for synthesized sources,
however, without offering most of the compiler directives (pragmas) to guide
implementation and optimization of the design. SYCL for Vitis components must be
linked to regular Vitis IP or kernel targets similar to pre-compiled libraries
via the `add_sycl_for_vitis_library` and `target_link_sycl_for_vitis_libraries`
functions. Note that this is a mostly untested CMake-based reimplementation of
the [Python-based flow](https://github.com/triSYCL/sycl/blob/sycl/unified/master/sycl/tools/sycl-vxx/bin/sycl_vxx.py)
originally provided by SYCL for Vitis. Please refer to the SYCL for Vitis
documentation for instructions on how to set things up.
