using Corleone
using LuxCore
using OrdinaryDiffEqTsit5
using StableRNGs
using Test

"""A small problem used to exercise the generic Lux layer contract."""
function _interface_rhs(u, p, t)
    return p[1] .* u
end

rng = StableRNG(901)
prob = ODEProblem(_interface_rhs, [1.0], (0.0, 1.0), [1.0])

@testset "Abstract layer interface" begin
    for layer in (
            SingleShootingLayer(prob, Tsit5()),
            MultipleShootingLayer(prob, Tsit5(), 0.5),
        )
        ps = LuxCore.initialparameters(rng, layer)
        st = LuxCore.initialstates(rng, layer)

        # These are the generic Lux operations that downstream optimization code uses.
        @test LuxCore.parameterlength(layer) > 0
        trajectory, new_state = layer(nothing, ps, st)
        @test trajectory isa Trajectory
        @test new_state isa NamedTuple
        @test !isempty(trajectory.t)
    end
end
