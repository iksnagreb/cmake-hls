# The minimum CMake version with sufficient support for list transformations
cmake_minimum_required(VERSION 3.27)

# First make sure the Vitis HLS tools are available
include(find_vitis)
# Add the target_enable_property utility to reduce boilerplate
include(enable_property)

# Vitis HLS default configuration file template if no CONFIG is give for the
# targets: A bare minimum of source files must be specified...
set(VITIS_HLS_CONFIG_TEMPLATE
    "[hls]"
    "syn.top=$<TARGET_PROPERTY:TOP>"
    "syn.cflags=$<JOIN:$<GENEX_EVAL:$<TARGET_PROPERTY:CXX_FLAGS>>, >"
    "syn.file=$<JOIN:$<GENEX_EVAL:$<TARGET_PROPERTY:ABSOLUTE_SOURCES>>, >"
    "tb.cflags=$<JOIN:$<GENEX_EVAL:$<TARGET_PROPERTY:CXX_FLAGS>>, >"
    "tb.file=$<JOIN:$<GENEX_EVAL:$<TARGET_PROPERTY:ABSOLUTE_TESTBENCH>>, >"
    "tb.file=$<JOIN:$<GENEX_EVAL:$<TARGET_PROPERTY:ABSOLUTE_SOURCES>>, >"
)

# Adds command line options to the Vitis HLS synthesis call
function(target_vitis_hls_options NAME)
    # Get the current state of the property
    get_target_property(VITIS_HLS_OPTIONS ${NAME} VITIS_HLS_OPTIONS)
    # Append the new options to the list
    set(OPTIONS "${VITIS_HLS_OPTIONS};${ARGN}")
    # Update the target property list
    set_target_properties(${NAME} PROPERTIES VITIS_HLS_OPTIONS "${OPTIONS}")
endfunction()

# Adds command line options to the Vitis kernel compile call
function(target_vitis_compile_options NAME)
    # Get the current state of the property
    get_target_property(VITIS_COMPILE_OPTIONS ${NAME} VITIS_COMPILE_OPTIONS)
    # Append the new options to the list
    set(OPTIONS "${VITIS_COMPILE_OPTIONS};${ARGN}")
    # Update the target property list
    set_target_properties(${NAME} PROPERTIES VITIS_COMPILE_OPTIONS "${OPTIONS}")
endfunction()

# Adds command line options to the Vitis link call
function(target_vitis_link_options NAME)
    # Get the current state of the property
    get_target_property(VITIS_LINK_OPTIONS ${NAME} VITIS_LINK_OPTIONS)
    # Append the new options to the list
    set(OPTIONS "${VITIS_LINK_OPTIONS};${ARGN}")
    # Update the target property list
    set_target_properties(${NAME} PROPERTIES VITIS_LINK_OPTIONS "${OPTIONS}")
endfunction()

# Adds TESTBENCH C++ sources to a Vitis HLS IP/kernel
function(target_testbench_sources NAME)
    # Get the current state of the property
    get_target_property(TESTBENCH ${NAME} TESTBENCH)
    # Append the new sources to the list
    set(SOURCES "${TESTBENCH};${ARGN}")
    # Update the target property list
    set_target_properties(${NAME} PROPERTIES TESTBENCH "${SOURCES}")
endfunction()

# Sets the top-level function property: Allows to select a different top-level
# if multiple kernels are present
function(target_top NAME TOP)
    set_target_properties(${NAME} PROPERTIES TOP ${TOP})
endfunction()

# Sets the part property of a Vitis HLS IP target
function(target_vitis_part NAME PART)
    set_target_properties(${NAME} PROPERTIES VITIS_PART ${PART})
endfunction()

# Sets the platform property of a Vitis HLS kernel target
function(target_vitis_platform NAME PLATFORM)
    set_target_properties(${NAME} PROPERTIES VITIS_PLATFORM ${PLATFORM})
endfunction()

# Custom commands and targets which instruct Vitis HLS to synthesize an IP from
# C++ sources. Optionally also generates testbench targets.
#
# Accept named list options, all of which (except for NAME) are optional and are
# passed to different parts of the C++/Vitis HLS flow:
#   NAME - Primary name of the design and exported IP, also specifies the
#       default name of the synthesized top-level function if not set via TOP
#   SOURCES - C++ source files passed to the Vitis HLS for synthesis and IP
#       export, will be linked to the testbench if specified
#   TESTBENCH - C++ source files which contain a main entrypoint to be
#       compiled into C++ and C++/RTL co-simulation
#   CONFIG - Configuration file template filled from CMake generator
#       expressions before passed to Vitis HLS calls
#   PART - Target part for Vitis HLS IP synthesis, can also be set or
#       overwritten via target_vitis_part
#   PLATFORM - Target platform for compiling and linking Vitis kernels, can
#       also be set or overwritten via target_vitis_platform
#   TOP - Name of the top level function, optional, defaults to NAME, can also
#       be set and overwritten via target_top
#
# An interface target called NAME will be exposed, which should be used to add
# further options and sources to the design. The exported IP is NAME.zip.
function(add_vitis_ip NAME)
    # ==========================================================================
    # 1. Parse function arguments pointing to various types of sources and
    #   configuration options
    # ==========================================================================
    # Named argument lists as defined above: These are the names accepted from
    # the command line, parsed arguments will be prefixed by ARGS_
    set(ARGUMENTS "SOURCES;TESTBENCH;CONFIG;PART;PLATFORM;TOP")
    # Parse the argument list into variables with names as above prefixed by
    # ARGS_. All arguments are optional, so not all variables might be set.
    cmake_parse_arguments(PARSE_ARGV 1 "ARGS" "" "" "${ARGUMENTS}")

    # ==========================================================================
    # 2. Interface target to be able to add compile options via the usual CMake
    #   functions and attributes. Could also be linked to C++ simulation.
    # ==========================================================================
    # Library target providing the primary interface to the whole collection of
    # custom targets and commands configured in the following
    add_library(${NAME} ${ARGS_SOURCES})

    # ==========================================================================
    # 3. Setup the target environment by adding properties, generating
    #   configuration and filling utility variables used by custom command below
    # ==========================================================================
    # Add the Vitis HLS headers to the include search paths
    target_include_directories(${NAME} PUBLIC ${VITIS_INCLUDE})

    # Enable the TESTBENCH property for this target which can be used to add
    # extra sources to the testbench
    target_enable_property(${NAME} TESTBENCH "${ARGS_TESTBENCH}")

    # Vitis HLS synthesis requires a top level function
    target_enable_property(${NAME} TOP ${NAME})

    # Overwrite the top-level function if specified via argument
    if(DEFINED ARGS_TOP)
        target_top(${NAME} ${ARGS_TOP})
    endif()

    # Optional target part name might be given when adding the custom target
    if(DEFINED ARGS_PART)
        # Register this as a target property which might be overwritten
        target_enable_property(${NAME} VITIS_PART "${ARGS_PART}")
    endif()

    # Optional target platform might be given when adding the custom target
    if(DEFINED ARGS_PLATFORM)
        # Register this as a target property which might be overwritten
        target_enable_property(${NAME} VITIS_PLATFORM "${ARGS_PLATFORM}")
    endif()

    # Register target properties for Vitis HLS command line options
    target_enable_property(${NAME} VITIS_HLS_OPTIONS)

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
    # Input sources files must be expanded to absolute paths as the tools won't
    # find the relative to the build directory
    set(SOURCES "$<PATH:ABSOLUTE_PATH,${SOURCES},${SOURCE_DIR}>")
    # Enable querying the absolute paths to all sources as a TARGET_PROPERTY
    target_enable_property(${NAME} ABSOLUTE_SOURCES "${SOURCES}")

    # Collect testbench sources files, these are a TARGET_PROPERTY which can be
    # extended after adding the target.
    set(TESTBENCH "$<GENEX_EVAL:$<${PROPERTY},TESTBENCH>>")
    # Input sources files must be expanded to absolute paths as the tools won't
    # find the relative to the build directory
    set(TESTBENCH "$<PATH:ABSOLUTE_PATH,${TESTBENCH},${SOURCE_DIR}>")
    # Enable querying the absolute paths to all sources as a TARGET_PROPERTY
    target_enable_property(${NAME} ABSOLUTE_TESTBENCH "${TESTBENCH}")

    # There might be an optional Vitis HLS configuration file template specified
    # Note: This makes Vitis calls almost fully customizable, the config could
    #   even introduce target attributes not explicitly introduced here
    if(DEFINED ARGS_CONFIG AND EXISTS ${ARGS_CONFIG})
        # Instantiate the configuration template by filling in all CMake
        # generator expressions for the target NAME
        file(GENERATE OUTPUT ${NAME}.cfg INPUT ${ARGS_CONFIG} TARGET ${NAME})
        # Set path to generated configuration file to be used in Vitis commands
        #   Note: This variable will be empty, thus without effect otherwise
        set(CONFIG --config ${NAME}.cfg)
        # If there is no Vitis HLS configuration file template specified, at least a
        # bare minimum pointing the tools to the sources must be provided
    else()
        # Configuration file template listing design and testbench files as well
        # as the name of the top-level function and the compiler flags
        string(JOIN "\n" TEMPLATE ${VITIS_HLS_CONFIG_TEMPLATE})
        # Instantiate the configuration template by filling in all CMake
        # generator expressions for the target NAME
        file(GENERATE OUTPUT ${NAME}.cfg CONTENT "${TEMPLATE}\n" TARGET ${NAME})
        # Set path to generated configuration file to be used in Vitis commands
        #   Note: This variable will be empty, thus without effect otherwise
        set(CONFIG --config ${NAME}.cfg)
    endif()

    # Working directory for Vitis HLS synthesis relative to the build directory
    set(WORKDIR ${CMAKE_CURRENT_BINARY_DIR}/${NAME}-syn)

    # ==========================================================================
    # 4. Vitis HLS C++ synthesis and HLS IP export compiling C++ sources into IP
    #   which can be consumed by Vivado designs
    # ==========================================================================
    # Run Vitis HLS synthesizing the IP from C++ design sources
    add_custom_command(
        # Produces the HLS IP packed as .zip file to be manually dropped into
        # Vivado designs or consumed by following steps
        OUTPUT ${WORKDIR} ${WORKDIR}/${NAME}.zip
        # @formatter:off
        # Run Vitis HLS v++ in HLS synthesis mode
        COMMAND ${VXX} -c --mode hls --work_dir ${WORKDIR} ${CONFIG}
            # Only prefixes platform if actually present
            $<LIST:TRANSFORM,$<${PROPERTY},VITIS_PLATFORM>,PREPEND,--platform=>
            # Only prefixes part if actually present
            $<LIST:TRANSFORM,$<${PROPERTY},VITIS_PART>,PREPEND,--part=>
            # Append all optional Vitis HLS options
            $<${PROPERTY},VITIS_HLS_OPTIONS>
        # @formatter:on
        # Produces intermediate files, logfiles and reports into the respective
        # working directory
        BYPRODUCTS vitis-comp.json
        # Depends on the design sources source files and the filled in
        # configuration file
        DEPENDS $<${PROPERTY},SOURCES> ${NAME}.cfg
        # Expand the list property as part of the command
        COMMAND_EXPAND_LISTS
        # Properly escape the command line
        VERBATIM
        # Add some message before building the target
        COMMENT "[1:1] [${NAME}.zip] HLS-Synthesis"
    )

    # Custom target triggering the HLS synthesize when ever the HLS IP archive
    # is requested
    add_custom_target(
        # Synthesized HLS IP archive
        ${NAME}.zip
        # Depends on the output of the HLS IP synthesis custom command
        DEPENDS ${WORKDIR}/${NAME}.zip
        # Register the target output as byproduct so it is removed by clean
        # TODO: This break ninja builds due to target depending on itself?
        # BYPRODUCTS ${NAME}.zip
        # Copy the output product out of the Vitis HLS working directory
        COMMAND cp ${WORKDIR}/${NAME}.zip ${NAME}.zip
    )

    # ==========================================================================
    # 5. Simulation test benches if testbench sources are specified: Compile an
    #   executable which integrates with IDEs and setup C++/RTL cosimulation
    # ==========================================================================

    # Setting up the testbench is optional, only generated if TESTBENCH sources
    # are given explicitly
    if(DEFINED ARGS_TESTBENCH)
        # Testbench executable combining all sources which should integrate well
        # with IDEs and uses the default C++ toolchain
        add_executable(tb_${NAME} "$<GENEX_EVAL:$<${PROPERTY},TESTBENCH>>")
        # Combine the Vitis HLS and SYCL source by linking to the library
        # targets above
        target_link_libraries(tb_${NAME} ${NAME})
        # Custom target executing the compiled C++ simulation testbench
        add_custom_target(
            # Suffix indicating this is "C Simulation" of the design
            tb_${NAME}_csim
            # Depends on building the C++ testbench executable above
            COMMAND tb_${NAME}
            # Add some message before running the target
            COMMENT "[Testbench] C++ Simulation of ${NAME}"
        )
        # Register C++/RTL simulation as a target executing the simulation flow
        # via the vitis-run command
        add_custom_target(
            # Test bench target name with suffix indicating C++/RTL cosimulation
            tb_${NAME}_cosim
            # Simulation is executed via the vitis-run command which should be
            # configured via the same configuration file already generated above
            COMMAND ${VITIS_RUN} --cosim ${CONFIG} --work_dir ${WORKDIR}
            # @formatter:off
            # Depends on the design and testbench sources as well as the already
            # synthesized IP located in WORKDIR
            DEPENDS $<GENEX_EVAL:$<${PROPERTY},TESTBENCH>>
                $<${PROPERTY},SOURCES> ${WORKDIR}
            # @formatter:on
            # Expand all list property as part of the command
            COMMAND_EXPAND_LISTS
            # Properly escape the command line
            VERBATIM
            # Add some message before running the target
            COMMENT "[Testbench] C++/RTL Co-Simulation of ${NAME}"
        )
    endif()
endfunction()


# Custom commands and targets which instruct Vitis HLS to synthesize a kernel
# from C++ sources. Optionally also generates testbench targets.
#
# Accept named list options, all of which (except for NAME) are optional and are
# passed to different parts of the C++/Vitis HLS flow:
#   NAME - Primary name of the design and exported IP, also specifies the
#       default name of the synthesized top-level function if not set via TOP
#   SOURCES - C++ source files passed to the Vitis HLS for synthesis and IP
#       export, will be linked to the testbench if specified
#   TESTBENCH - C++ source files which contain a main entrypoint to be
#       compiled into C++ and C++/RTL co-simulation
#   CONFIG - Configuration file template filled from CMake generator
#       expressions before passed to Vitis HLS calls
#   PART - Target part for Vitis HLS IP synthesis, can also be set or
#       overwritten via target_vitis_part
#   PLATFORM - Target platform for compiling and linking Vitis kernels, can
#       also be set or overwritten via target_vitis_platform
#   TOP - Name of the top level function, optional, defaults to NAME, can also
#       be set and overwritten via target_top
#
# An interface target called NAME will be exposed, which should be used to add
# further options and sources to the design. The exported kernel is NAME.xclbin.
function(add_vitis_kernel NAME)
    # ==========================================================================
    # 1. Parse function arguments pointing to various types of sources and
    #   configuration options
    # ==========================================================================
    # Named argument lists as defined above: These are the names accepted from
    # the command line, parsed arguments will be prefixed by ARGS_
    set(ARGUMENTS "SOURCES;TESTBENCH;CONFIG;PART;PLATFORM;TOP")
    # Parse the argument list into variables with names as above prefixed by
    # ARGS_. All arguments are optional, so not all variables might be set.
    cmake_parse_arguments(PARSE_ARGV 1 "ARGS" "" "" "${ARGUMENTS}")

    # ==========================================================================
    # 2. Reuse HLS IP synthesis and testbench commands as well as the interface
    #   target from the add_vitis_ip custom target
    # ==========================================================================
    # Just forward all arguments to the Vitis HLS IP synthesis target... This
    # will also take care of configuring testbench targets
    add_vitis_ip(${NAME} ${ARGN})

    # ==========================================================================
    # 3. Setup the target environment by adding properties, generating
    #   configuration and filling utility variables used by custom command below
    # ==========================================================================
    # Most of this is already done by the add_vitis_ip call, just add the
    # necessary extras for kernel compile and link...

    # Shortcut for querying properties of the target NAME in CMake generator
    # expressions
    set(PROPERTY "TARGET_PROPERTY:${NAME}")

    # Path to the directory containing all sources files for this target, path
    # managed by CMake
    set(SOURCE_DIR "$<${PROPERTY},SOURCE_DIR>")
    # Input sources files must be expanded to absolute paths as the tools won't
    # find the relative to the build directory
    set(SOURCES "$<PATH:ABSOLUTE_PATH,$<${PROPERTY},SOURCES>,${SOURCE_DIR}>")

    # Register target properties for Vitis HLS compile command line options
    target_enable_property(${NAME} VITIS_COMPILE_OPTIONS)
    # Register target properties for Vitis HLS link command line options
    target_enable_property(${NAME} VITIS_LINK_OPTIONS)

    # Working directory for the Vitis HLS compile command
    set(COMPILE_DIR ${CMAKE_CURRENT_BINARY_DIR}/${NAME}-compile)
    # Working directory for the Vitis link command
    set(LINK_DIR ${CMAKE_CURRENT_BINARY_DIR}/${NAME}-link)

    # ==========================================================================
    # 4. Vitis HLS kernel synthesis and linking steps combining the IP with the
    #   target platform for deployment
    # ==========================================================================

    # Compiles a Vitis kernel .xo file from the sources, arbitrary options can
    # be added via target_vitis_compile_options
    add_custom_command(
        # Compiled Vitis HLS kernel file which can be used by the Vitis link
        OUTPUT ${NAME}.xo ${COMPILE_DIR}
        # @formatter:off
        # Run Vitis HLS v++ in HLS kernel synthesis mode
        COMMAND ${VXX} -c -k $<${PROPERTY},TOP> -o ${NAME}.xo
            # Only prefixes platform if actually present
            $<LIST:TRANSFORM,$<${PROPERTY},VITIS_PLATFORM>,PREPEND,--platform=>
            # Only prefixes part if actually present
            $<LIST:TRANSFORM,$<${PROPERTY},VITIS_PART>,PREPEND,--part=>
            # Append all optional Vitis HLS options
            $<${PROPERTY},VITIS_COMPILE_OPTIONS>
            # Append compilation flags
            $<GENEX_EVAL:$<${PROPERTY},CXX_FLAGS>>
            # Directory for temporary files
            --temp_dir ${COMPILE_DIR}
            # Directory for logfiles
            --log_dir ${COMPILE_DIR}
            # Append all input source files
            ${SOURCES}
        # @formatter:on
        # Produces intermediate files, logfiles and reports into the respective
        # working directory
        BYPRODUCTS ${NAME}.xo.compile_summary v++_${NAME}.log xcd.log
        # Depends on the SYCL-compiled sources as well as the regular Vitis HLS
        # source files
        DEPENDS $<${PROPERTY},SOURCES>
        # Expand the list property as part of the command
        COMMAND_EXPAND_LISTS
        # Properly escape the command line
        VERBATIM
        # Add some message before building the target
        COMMENT "[1:2] [${NAME}.xo] Compile"
    )

    # Links a Vitis kernel .xclbin file from the compiled kernel, arbitrary
    # options can be added via target_vitis_link_options
    add_custom_command(
        # Linked Vitis kernel executable which can be used to program the
        # accelerator device
        OUTPUT ${NAME}.xclbin ${LINK_DIR}
        # @formatter:off
        COMMAND ${VXX} -l -o ${NAME}.xclbin
            # Only prefixes platform if actually present
            $<LIST:TRANSFORM,$<${PROPERTY},VITIS_PLATFORM>,PREPEND,--platform=>
            # Only prefixes part if actually present
            $<LIST:TRANSFORM,$<${PROPERTY},VITIS_PART>,PREPEND,--part=>
            # Append all optional Vitis HLS options
            $<GENEX_EVAL:$<${PROPERTY},VITIS_LINK_OPTIONS>>
            # Append compilation flags
            $<GENEX_EVAL:$<${PROPERTY},CXX_FLAGS>>
            # Directory for temporary files
            --temp_dir ${LINK_DIR}
            # Directory for logfiles
            --log_dir ${LINK_DIR}
            # Append the already compiled Vitis kernel
            ${NAME}.xo
        # @formatter:on
        # Produces intermediate files, logfiles and reports into the respective
        # working directory
        BYPRODUCTS ${NAME}.ltx ${NAME}.xclbin.info ${NAME}.xclbin.link_summary
        # Depends on the compiled Vitis kernel
        DEPENDS ${NAME}.xo
        # Expand the list property as part of the command
        COMMAND_EXPAND_LISTS
        # Properly escape the command line
        VERBATIM
        # Add some message before building the target
        COMMENT "[2:2] [${NAME}.xclbin] Link"
    )
endfunction()
