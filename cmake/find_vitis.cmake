# Start looking for Vitis HLS programs and libraries
message(CHECK_START "Looking for Vitis HLS")

# Initially assume Vitis has not been found
set(VITIS_FOUND NO)

# Start looking at locations and versions pointed to by environment variables
set(XILINX_ROOT $ENV{XILINX_ROOT})
set(XILINX_VITIS $ENV{XILINX_VITIS})
set(XILINX_HLS $ENV{XILINX_HLS})
set(XILINX_VERSION $ENV{XILINX_VERSION})

# If no explicit path to Vitis is given, but the root of the Xilinx tools and a
# version string, try the most likely location
if(NOT DEFINED XILINX_VITIS AND DEFINED XILINX_ROOT AND DEFINED XILINX_VERSION)
    set(XILINX_VITIS "${XILINX_ROOT}/Vitis/${XILINX_VERSION}")
endif()

# If no explicit path to Vitis HLS is given, but the root of the Xilinx tools
# and a  version string, try the most likely location
if(NOT DEFINED XILINX_HLS AND DEFINED XILINX_ROOT AND DEFINED XILINX_VERSION)
    set(XILINX_HLS "${XILINX_ROOT}/Vitis_HLS/${XILINX_VERSION}")
endif()

# Remove Vitis programs from cache to avoid issues when switching versions...
unset(VXX CACHE)
unset(VITIS_RUN CACHE)

# Vitis HLS C++ compiler to synthesize and link the whole design and the
# vitis-run command which can be used for running test benches
find_program(VXX v++ PATHS ${XILINX_VITIS} ${XILINX_VITIS}/bin REQUIRED)
find_program(VITIS_RUN vitis-run PATHS ${XILINX_VITIS} ${XILINX_VITIS}/bin)

# If these two have been found but the environment variables are not set, derive
# the path and version from the location where v++ is found
if(NOT DEFINED XILINX_VITIS AND EXISTS ${VXX})
    # Strip the last two components of the path, which should be /bin/v++, to
    # get to the version string which ends the path to Vitis
    string(REPLACE "/" ";" TMP "${VXX}")
    list(REMOVE_AT TMP -1)
    list(REMOVE_AT TMP -1)
    # Xilinx tools version string should now be the last component which can be
    # extracted from the list
    list(GET TMP -1 XILINX_VERSION)
    # The whole path in TMP should also be the root for the selected Vitis
    # installation, just revert back from a list to a proper path string
    string(REPLACE ";" "/" XILINX_VITIS "${TMP}")

    # Strip the last two components, which should be Vitis/${XILINX_VERSION}, to
    # get to the root of the Xilinx tools installations
    list(REMOVE_AT TMP -1)
    list(REMOVE_AT TMP -1)
    # Revert the installation root back from a list to a proper path string to
    # be exported so the user could manually assemble paths to the other tools
    # of the platform repository not explicitly exposed here
    string(REPLACE ";" "/" XILINX_ROOT "${TMP}")
    # Guess the most likely path to the Vitis HLS installation relative to the
    # Xilinx tools root
    # Note: This changed with 2024.2 (2024.1?) to be just "Vitis", but this will
    # be detected and corrected when looking for the SPIR library below
    string(REPLACE ";" "/" XILINX_HLS "${TMP};Vitis_HLS;${XILINX_VERSION}")
endif()

# Path to HLS SPIR library distributed with Vitis HLS
find_file(SPIR libspir64-39-hls.bc PATHS ${XILINX_HLS}/lnx64/lib NO_CACHE)

# If the SPIR library could not be found the derived path might be wrong
if(NOT EXISTS ${SPIR})
    # Try again with HLS path the same as Vitis
    set(XILINX_HLS ${XILINX_VITIS})
    # Path to HLS SPIR library distributed with Vitis HLS
    find_file(SPIR libspir64-39-hls.bc PATHS ${XILINX_HLS}/lnx64/lib NO_CACHE)
endif()

# Path to Vitis HLS LLVM and clang binaries
set(VITIS_LLVM_BIN "${XILINX_HLS}/lnx64/tools/clang-3.9-csynth/bin")

# Remove Vitis programs from cache to avoid issues when switching versions...
unset(VITIS_CLANG CACHE)
unset(VITIS_LLVM_LINK CACHE)
unset(VITIS_LLVM_AS CACHE)
unset(VITIS_OPT CACHE)

# Vitis HLS version of the clang C++ compiler
find_program(VITIS_CLANG clang++ HINTS ${VITIS_LLVM_BIN} NO_DEFAULT_PATH)
# Vitis version of the llvm-link linker command
find_program(VITIS_LLVM_LINK llvm-link PATHS ${VITIS_LLVM_BIN} NO_DEFAULT_PATH)
# Vitis version of the llvm-as assembler command
find_program(VITIS_LLVM_AS llvm-as PATHS ${VITIS_LLVM_BIN} NO_DEFAULT_PATH)
# Vitis version of the opt optimizer command
find_program(VITIS_OPT opt PATHS ${VITIS_LLVM_BIN} NO_DEFAULT_PATH)

# Consider Vitis to be found if VXX and the version are present
if(EXISTS ${VXX} AND DEFINED XILINX_VERSION)
    set(VITIS_FOUND YES)
endif()

# Function testing for the Vitis HLS version rejecting configuration if the
# detected version is smaller
function(vitis_minimum_required)
    # A named single argument VERSION must be specified
    cmake_parse_arguments(PARSE_ARGV 0 "ARGS" "" "VERSION" "")
    # Compare the specified version to the detected version
    if(${XILINX_VERSION} VERSION_LESS ${ARGS_VERSION})
        # Fail with error message reporting the required version
        message(FATAL_ERROR "Vitis ${ARGS_VERSION} or higher is required.\
            You are running version ${XILINX_VERSION}")
    endif()
endfunction()

# Set the Vitis HLS include path
if(${VITIS_FOUND})
    # Expose the path to the Vitis HLS includes
    set(VITIS_INCLUDE ${XILINX_HLS}/include)
    # Add Vitis HLS headers to the include search paths to make this available
    # to any target
    include_directories(${VITIS_INCLUDE})
endif()

# Status message reporting location and version of the Xilinx tools found
message(STATUS "Found at ${XILINX_ROOT}")
message(STATUS "Found version ${XILINX_VERSION}")
# Done looking for Vitis HLS
message(CHECK_PASS "done")
