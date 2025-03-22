# The minimum CMake version with sufficient support for list transformations
cmake_minimum_required(VERSION 3.27)

# Make sure the SYCL for Vitis HLS tools and Vitis HLS itself are available
include(find_sycl)
include(find_vitis)

# Add the target_enable_property utility to reduce boilerplate
include(enable_property)

# Default options and compiler passes of SYCL to Vitis HLS LLVM IR conversion
include(options/hls_opt_options)
include(options/hls_opt_passes)

# Default options and compiler passes of SYCL to Vitis HLS LLVM IR downgrade
include(options/ir_downgrade_options)
include(options/ir_downgrade_passes)

# Custom commands and targets using SYCL for Vitis for compiling C++ to LLVM IR
# which can be consumed by Vitis HLS
#
# Accept named list options, all of which (except for NAME) are optional and are
# passed to different parts of the SYCL C++/Vitis HLS flow:
#   NAME - Primary name of the converted and exported LLVM IR library to be
#       linked to a Vitis HLS IP or kernel
#   SOURCES - C++ source files passed to the SYCL for Vitis compilation,
#       optimization and conversion pass
#   LINK_SPIR - Enables linking the HLS SPIR library to the LLVM IR as the final
#       step of conversion
#
# An interface target called NAME will be exposed, which should be used to add
# further options and sources. The exported library is NAME.xpirbc.
function(add_sycl_for_vitis_library NAME)
    # ==========================================================================
    # 1. Parse function arguments pointing to various types of sources and
    #   configuration options
    # ==========================================================================
    # Named argument lists as defined above: These are the names accepted from
    # the command line, parsed arguments will be prefixed by ARGS_
    set(ARGUMENTS "SOURCES;")
    # Parse the argument list into variables with names as above prefixed by
    # ARGS_. All arguments are optional, so not all variables might be set.
    cmake_parse_arguments(PARSE_ARGV 1 "ARGS" "LINK_SPIR" "" "${ARGUMENTS}")

    # ==========================================================================
    # 2. Dummy library target to be able to add compile options via the usual
    #   CMake functions and attributes. Could also be linked to C++ simulation.
    # ==========================================================================
    # Library target providing the primary interface to the whole collection of
    # custom targets and commands configured in the following
    add_library(${NAME} ${ARGS_SOURCES})

    # ==========================================================================
    # 3. Setup the target environment by adding properties, generating
    #   configuration and filling utility variables used by custom command below
    # ==========================================================================
    # Shortcut for querying properties of the target NAME in CMake generator
    # expressions
    set(PROPERTY "TARGET_PROPERTY:${NAME}")

    # Path to the directory containing all sources files for this target, path
    # managed by CMake
    set(SOURCE_DIR "$<${PROPERTY},SOURCE_DIR>")

    # Generator expression configuring the C++ compiler to compile for a
    # specific version of the language
    set(CXX_STANDARD "$<${PROPERTY},CXX_STANDARD>")
    # Prepend the command line option as understood by gcc and clang (and Vitis)
    set(CXX_STANDARD "$<LIST:TRANSFORM,${CXX_STANDARD},PREPEND,--std=c++>")

    # Assemble C++ compiler options shared by almost all targets, except for the
    # C++ version which is not passed to the Vitis HLS compiler
    set(CXX_FLAGS "$<${PROPERTY},COMPILE_OPTIONS>;")
    # Add compile options marked as INTERFACE options for the target
    string(APPEND CXX_FLAGS "$<${PROPERTY},INTERFACE_COMPILE_OPTIONS>;")
    # Collect list of compile definitions
    set(DEFINITIONS "$<${PROPERTY},COMPILE_DEFINITIONS>")
    # Add compile definitions
    string(APPEND CXX_FLAGS "$<LIST:TRANSFORM,${DEFINITIONS},PREPEND,-D>;")
    # Collect list of compile definitions marked as INTERFACE options for the
    # target
    set(DEFINITIONS "$<${PROPERTY},INTERFACE_COMPILE_DEFINITIONS>")
    # Add compile definitions
    string(APPEND CXX_FLAGS "$<LIST:TRANSFORM,${DEFINITIONS},PREPEND,-D>;")
    # Collect the list of include search paths for the target
    set(INCLUDES "$<${PROPERTY},INCLUDE_DIRECTORIES>")
    # Add the include search path to the compiler command lines
    string(APPEND CXX_FLAGS "$<LIST:TRANSFORM,${INCLUDES},PREPEND,-I>;")
    # Add the selected C++ standard to the compiler flags
    string(APPEND CXX_FLAGS "${CXX_STANDARD}")

    # Register C++ compiler flags as target property to be available in
    # generator expressions
    target_enable_property(${NAME} CXX_FLAGS)

    # Collect design sources files, these are a TARGET_PROPERTY which can be
    # extended after adding the target.
    set(SOURCES "$<${PROPERTY},SOURCES>")
    # Intermediate bitcode files produced by compiler and consumed by linker
    #   Note: Keep these as relative paths, will end up in build directory
    set(INTERMEDIATES "$<PATH:REPLACE_EXTENSION,${SOURCES},bc>")
    # Input sources files must be expanded to absolute paths as the tools won't
    # find the relative to the build directory
    set(SOURCES "$<PATH:ABSOLUTE_PATH,${SOURCES},${SOURCE_DIR}>")
    # Enable querying the absolute paths to all sources as a TARGET_PROPERTY
    target_enable_property(${NAME} ABSOLUTE_SOURCES "${SOURCES}")

    # Select the output product depending on whether this library should be
    # linked to the HLS SPIR library
    if(${ARGS_LINK_SPIR})
        set(STEPS 5)
    else()
        set(STEPS 4)
    endif()

    # ==========================================================================
    # 4. Setup SYCL to Vitis HLS preprocessing of the sources: Linking input
    #   files, conversion and optimization passes... LLVM IR downgrading.
    # ==========================================================================

    # 4.1 Compile SOURCES to LLVM IR bitcode via SYCL clang++
    add_custom_command(
        # Produces LLVM IR bitcode files for the linked input sources
        OUTPUT ${NAME}.1.bc
        # Compile each individual C++ source file to LLVM IR bitcode
        COMMAND ${SYCL_FOR_VITIS_CLANG} -emit-llvm -c ${CXX_FLAGS} ${SOURCES}
        # Link the individual LLVM IR bitcode files to a single file
        COMMAND ${SYCL_FOR_VITIS_LLVM_LINK} ${INTERMEDIATES} -o ${NAME}.1.bc
        # Get rid of all the intermediate files. These cannot be listed OUTPUT
        # or BYPRODUCTS...
        COMMAND rm ${INTERMEDIATES}
        # Depends on the input sources tracking any changes
        DEPENDS ${SOURCES}
        # Expand the list property as part of the command
        COMMAND_EXPAND_LISTS
        # Properly escape the command line
        VERBATIM
        # Add some message before building the target
        COMMENT "[1:${STEPS}] [${NAME}.1.bc] Compile"
    )

    # Initialize conversion optimization options and passes inheriting defaults
    # from the global scope
    target_enable_property(${NAME} HLS_OPT_OPTIONS)
    target_enable_property(${NAME} HLS_OPT_PASSES)

    # 3.2 SYCL for Vitis HLS optimization passes applied before conversion and
    # LLVM IR downgrade
    add_custom_command(
        # Produces LLVM IR files for the SYCL to HLS conversion
        OUTPUT ${NAME}.2.ll
        # @formatter:off
        # Run a selected set of conversion and optimization passes
        COMMAND ${SYCL_FOR_VITIS_OPT} -S -o ${NAME}.2.ll ${NAME}.1.bc
            # Add optimization options from the target property
            $<${PROPERTY},HLS_OPT_OPTIONS>
            # Add optimization passes form the target property
            -passes=$<JOIN:$<${PROPERTY},HLS_OPT_PASSES>,,>
        # @formatter:on
        # Depends on the compiled and linked LLVM IR bitcode
        DEPENDS ${NAME}.1.bc
        # Expand the list property as part of the command
        COMMAND_EXPAND_LISTS
        # Properly escape the command line
        VERBATIM
        # Add some message before building the target
        COMMENT "[2:${STEPS}] [${NAME}.2.ll] Convert"
    )

    # Initialize LLVM IR downgrade options and optimization passes inheriting
    # defaults from the global scope
    target_enable_property(${NAME} IR_DOWNGRADE_OPTIONS)
    target_enable_property(${NAME} IR_DOWNGRADE_PASSES)

    # 3.3 LLVM IR downgrade to be compatible with IR consumed by Vitis HLS
    add_custom_command(
        # Produces LLVM IR files for the downgrade IR version compatible with
        # Vitis HLS
        OUTPUT ${NAME}.3.1.ll ${NAME}.3.ll ${NAME}.kernel.propgen.json
        # @formatter:off
        # Run a selected set of conversion and optimization passes
        COMMAND ${SYCL_FOR_VITIS_OPT} -S -o ${NAME}.3.1.ll ${NAME}.2.ll
            # Additional JSON which can to be consumed by the Vitis link step
            --sycl-kernel-propgen-output ${NAME}.kernel.propgen.json
            # Add optimization options from the target property
            $<${PROPERTY},IR_DOWNGRADE_OPTIONS>
            # Add optimization passes form the target property
            -passes=$<JOIN:$<${PROPERTY},IR_DOWNGRADE_PASSES>,,>
        # Run the actual LLVM IR downgrade pass
        COMMAND ${SYCL_FOR_VITIS_OPT} -S ${NAME}.3.1.ll -o ${NAME}.3.ll
            # This is the actual LLVM IR downgrade pass
            -passes=vxxIRDowngrader
        # @formatter:on
        # Depends on the optimized LLVM IR from the previous step
        DEPENDS ${NAME}.2.ll
        # Expand the list property as part of the command
        COMMAND_EXPAND_LISTS
        # Properly escape the command line
        VERBATIM
        # Add some message before building the target
        COMMENT "[3:${STEPS}] [${NAME}.3.ll] IR Downgrade"
    )

    # 3.4 Assemble downgraded LLVM IR to bitcode consumed by Vitis HLS
    add_custom_command(
        # Produces LLVM IR bitcode files compatible with Vitis HLS
        OUTPUT ${NAME}.4.xpirbc
        # Vitis HLS assembler converts LLVM IR to bitcode format for Vitis HLS
        COMMAND ${VITIS_LLVM_AS} ${NAME}.3.ll -o ${NAME}.4.xpirbc
        # Depends on the downgraded LLVM IR from the previous step
        DEPENDS ${NAME}.3.ll
        # Expand the list property as part of the command
        COMMAND_EXPAND_LISTS
        # Properly escape the command line
        VERBATIM
        # Add some message before building the target
        COMMENT "[4:${STEPS}] [${NAME}.4.xpirbc] Assemble"
    )

    # 3.5 Link with HLS SPIR library which is a part of Vitis HLS
    add_custom_command(
        # Produces LLVM IR bitcode files compatible with Vitis HLS
        OUTPUT ${NAME}.5.xpirbc
        # Vitis HLS assembler converts LLVM IR to LLVM bitcode format for Vitis
        # HLS
        COMMAND ${VITIS_LLVM_LINK} ${NAME}.4.xpirbc ${SPIR} -o ${NAME}.5.xpirbc
        # Depends on the assembled LLVM IR bitcode from the previous step
        DEPENDS ${NAME}.4.xpirbc
        # Expand the list property as part of the command
        COMMAND_EXPAND_LISTS
        # Properly escape the command line
        VERBATIM
        # Add some message before building the target
        COMMENT "[5:${STEPS}] [${NAME}.5.xpirbc] Link SPIR"
    )

    # Custom target triggering the final output product to be build
    add_custom_target(
        # The final pre-compiled and downgraded LLVM IR bitcode
        ${NAME}.xpirbc
        # Depends on the assembled and linked output selected above
        DEPENDS ${NAME}.${STEPS}.xpirbc
        # The final pre-compiled and downgraded LLVM IR bitcode
        BYPRODUCTS ${NAME}.xpirbc
        # Compy the selected output to the final output
        COMMAND cp ${NAME}.${STEPS}.xpirbc ${NAME}.xpirbc
    )
endfunction()

# Links a SYCL for Vitis compiled library to a Vitis HLS IP or kernel target
function(target_link_sycl_for_vitis_libraries NAME)
    # Link the libraries to the interface library of NAME for C++ compilation
    target_link_libraries(${NAME} ${ARGN})
    # Link multiple libraries at once, but look up sources for each individually
    foreach(L ${ARGN})
        # Link the libraries to the HLS synthesis by adding the pre-compiled and
        # downgraded LLVM IR bitcode to the sources
        target_sources(${NAME} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/${L}.xpirbc)
        # Linking the library to the HLS testbench C++ simulation requires the
        # original sources
        target_testbench_sources(${NAME} "$<TARGET_PROPERTY:${L},SOURCES>")
    endforeach()
endfunction()
