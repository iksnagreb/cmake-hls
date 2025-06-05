# Needs the Vitis HLS tools and custom targets
include(vitis)

# There seem to be some issues with configuration options accepted by 2022.2...
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
