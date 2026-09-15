using CorleoneOED
using LinearAlgebra
using LuxCore
using OrdinaryDiffEqTsit5
using Random
using Test

struct TraceCriterion <: CorleoneOED.AbstractCriterion end

function (criterion::TraceCriterion)(F::Symmetric)
    return tr(F)
end

function _criterion_rhs(u, p, t)
    return p[1] .* u
end

prob = ODEProblem(_criterion_rhs, [1.0], (0.0, 1.0), [1.0])
base_layer = SingleShootingLayer(
    prob,
    Tsit5();
    controls = [],
    bounds_p = ([1.0], [1.0]),
)
layer = OEDLayer{false}(
    base_layer;
    params = [1],
    measurements = [
        ControlParameter([0.0, 0.5], controls = ones(2), bounds = (0.0, 1.0)),
    ],
    observed = (u, p, t) -> [u[1]],
)
ps, st = LuxCore.setup(Random.default_rng(), layer)

@testset "Generic AbstractCriterion contract" begin
    value, new_state = TraceCriterion()(layer, nothing, ps, st)
    @test value isa Real
    @test new_state isa NamedTuple
end
