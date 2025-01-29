# Developer Documentation

## Tips for channels and tasks

Tasks have an ~1 microsecond overhead, so the number of tasks should always be minimized (maybe 2*nthreads() is a good number).

Channels are not that bad but should ideally be neither empty nor full for best performance.  In practice this may not really matter though.

## Testing

This package uses TestItems.jl, a testing framework that allows structuring tests into individual, independent `@testitem` blocks that can be run independently.

TestItems.jl integrates with both VSCode and the command line, making it easy to write and run tests during development.

### Running Tests

To run all tests, simply run `Pkg.test("RangeExtractor")` from the Julia REPL.

To run a subset of tests, you can use TestItemRunner.jl to filter tests.  Here's an example from the TestItems.jl documentation:

```julia
using TestItemRunner
@run_package_tests filter=ti->( !(:skipci in ti.tags) && endswith(ti.filename, "test_foo.jl") )
```

### Adding New Tests

Tests can be added to any file in the `test` directory by creating a new `@testitem` block. For example:

```julia
@testitem "My Test" tags=[:Demo] begin
    # Test code here
    @test 1 + 1 == 2
    @test 2 + 2 != 5

    using Statistics

    @test mean([1, 2, 3]) == 2
end
```

Note that `@testitem` blocks ought to be self-contained, so all `using`s should lie within the block.  `using Test, TileExtractor` is executed by default by TestItems.jl, so you don't need to include it in your test.
