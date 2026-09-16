using Corleone
using Random
using Test

rng = MersenneTwister(1)
controls = ControlParameter(
    collect(0.0:0.25:0.75);
    name = :u,
    controls = [0.1, 0.2, 0.3, 0.4],
    bounds = (0.0, 1.0),
)

@test Corleone.get_timegrid(controls, (0.0, 0.75)) == [0.0, 0.25, 0.5]
@test Corleone.get_controls(rng, controls) == [0.1, 0.2, 0.3, 0.4]
@test Corleone.get_bounds(controls) == (zeros(4), ones(4))
@test Corleone.check_consistency(rng, controls) === nothing
