// EXIT_SUCCESS
#include <cstdlib>
// assert
#include <cassert>

// Top-level function to be tested, defined in a separate design file
void adder(int a, int b, int &out);

// Testbench entrypoint for C++ Simulation and C++/RTL Co-Simulation
int main(int, char **) {
    // Output variable connected to the adder
    int out = 0;
    // Call the adder top-level function
    adder(1, 2, out);
    // Check the result of the addition
    assert(out == 3);
    // Test successfully passed
    return EXIT_SUCCESS;
}
