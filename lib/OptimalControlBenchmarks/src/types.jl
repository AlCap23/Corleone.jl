"""
$(TYPEDEF)

Description of one benchmark problem registered by `load_benchmarks`.

# Fields
$(FIELDS)

This is a developer type. Benchmark packages should provide a constructor with the
same callable contract as `make_problem` rather than depending on implementation
details of the benchmark registry.
"""
struct OptimalControlBenchmark
    "Stable identifier used in benchmark output."
    name::Symbol
    "Human-readable description of the problem."
    description::String
    "Callable accepting `BenchmarkGrids` and returning benchmark problem data."
    make_problem::Function
end

"""
$(TYPEDEF)

The grids used by an optimal-control benchmark constructor.

# Fields
$(FIELDS)

# Usage contract
Each grid contains the time points used for the corresponding discretization. A
benchmark constructor accepts a `BenchmarkGrids` value and returns the problem data
consumed by `run_all`.
"""
struct BenchmarkGrids
    "Control discretization points."
    control_grid::Vector{Float64}
    "Multiple-shooting points."
    shooting_grid::Vector{Float64}
    "Points at which path or terminal constraints are evaluated."
    constraint_grid::Vector{Float64}
end
