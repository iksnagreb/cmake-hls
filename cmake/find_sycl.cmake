# Start looking for SYCL + Vitis HLS integration programs and libraries
message(CHECK_START "Looking for SYCL for Vitis HLS")

# Initially assume SYCL has not been found
set(SYCL_FOR_VITIS_FOUND NO)

# If now variable already points to the root of the SYCL for Vitis installation,
# try to get this from the environment variables
if(NOT DEFINED SYCL_FOR_VITIS_ROOT OR NOT EXISTS ${SYCL_FOR_VITIS_ROOT})
    # This is the default variable to look for
    set(SYCL_FOR_VITIS_ROOT $ENV{SYCL_FOR_VITIS_ROOT})
    # Might still not be found, so check another one...
    if(NOT DEFINED SYCL_FOR_VITIS_ROOT OR NOT EXISTS ${SYCL_FOR_VITIS_ROOT})
        # Second option not explicitly referring to Vitis
        set(SYCL_FOR_VITIS_ROOT $ENV{SYCL_ROOT})
    endif()
endif()

# Path to SYCL for Vitis LLVM and clang binaries
set(SYCL_FOR_VITIS_BIN "${SYCL_FOR_VITIS_ROOT}/build/bin")

# The sycl_vxx.py script which implements th SYCL to Vitis HLS conversion and
# build flow in python is used to identify this as a SYCL for Vitis installation
find_program(SYCL_VXX sycl_vxx.py HINTS ${SYCL_FOR_VITIS_BIN} NO_CACHE REQUIRED)

# Utility function for detecting various SYCL for Vitis programs
function(find_sycl_for_vitis_program VAR PROGRAM)
    # Prefix all VARs by SYCL_FOR_VITIS_ to avoid confusion with normal versions
    # of these tools, e.g. CLANG vs. SYCL_FOR_VITIS_CLANG
    set(VAR "SYCL_FOR_VITIS_${VAR}")
    # Forward to the usual find_program function but do not search the system's
    # default paths to not find a "normal" version of the tools by accident
    find_program(${VAR} ${PROGRAM} HINTS ${SYCL_FOR_VITIS_BIN} NO_DEFAULT_PATH)
endfunction()

# SYCL version of the clang command
find_sycl_for_vitis_program(CLANG clang++)
# SYCL version of the llvm-link linker command
find_sycl_for_vitis_program(LLVM_LINK llvm-link)
# SYCL version of the llvm-as assembler command
find_sycl_for_vitis_program(LLVM_AS llvm-as)
# SYCL version of the opt optimizer command
find_sycl_for_vitis_program(OPT opt HINTS)

# Consider SYCL for Vitis to be found if SYCL_FOR_VITIS_CLANG is present
if(EXISTS ${SYCL_FOR_VITIS_ROOT} AND EXISTS ${SYCL_FOR_VITIS_CLANG})
    set(SYCL_FOR_VITIS_FOUND YES)
endif()

# Always force SYCL for Vitis clang to target Vitis IP
set(SYCL_FOR_VITIS_CLANG "${SYCL_FOR_VITIS_CLANG};--target=vitis_ip-xilinx")

# Status message reporting location of the SYCL for Vitis installation
message(STATUS "Found at ${SYCL_FOR_VITIS_ROOT}")
# Done looking for SYCL for Vitis
message(CHECK_PASS "done")