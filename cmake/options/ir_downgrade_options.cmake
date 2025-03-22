# List of default LLVM IR downgrade options taken from the sycl_vxx.py
set(IR_DOWNGRADE_OPTIONS
    --lower-mem-intr-to-llvm-type
    --lower-mem-intr-full-unroll
    --lower-delayed-sycl-metadata
    --sycl-prepare-after-O3
    --unroll-only-when-forced
    -strip-debug
)