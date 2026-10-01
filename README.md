# QuadFuck - A brainfuck interpreter written in pure x86_64 assembly

To obtain the interpreter, simply run `make`. An executable will be created at `./build/main`

The interpreter requests one positional argument for the filename to run.

For errors, look at the last error code (`$?` in bash, `$env.LAST_EXIT_CODE` in nu) and the error message and google it.
