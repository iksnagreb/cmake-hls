# Needs the Vitis HLS tools and custom targets
include(vitis)

# Has not been tested below 2022.2...
vitis_minimum_required(VERSION 2022.2)

# This demo project builds a simple adder kernel with Vitis HLS also adding C++
# Simulation and C++/RTL Co-Simulation. Targets the Alveo U280 accelerator card.
add_vitis_kernel(
    # Name of the interface target, default name of the top-level function
    adder
    # Design C++ sources to be synthesize
    SOURCES adder.cpp
    # C++ Sources only used by the simulation
    TESTBENCH adder_tb.cpp
    # Alveo U280 platform
    PLATFORM xilinx_u280_gen3x16_xdma_1_202211_1
)
