# List of default LLVM IR downgrade passes taken from the sycl_vxx.py
set(IR_DOWNGRADE_PASSES
    "lower-sycl-metadata"
    "globaldce"
    "prepare-sycl"
    "loop-unroll"
    "kernelPropGen"
    "globaldce"
)
