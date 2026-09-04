# ---------------------------------------------------------------------------
# DynamicFunctions – a container layer that evaluates a tuple of
# DynamicFunctionLayers, either out-of-place (concatenating their outputs)
# or in-place (writing each function's scalar output into a shared vector).
# ---------------------------------------------------------------------------

# A real Trajectory (not a fake) to satisfy the layer's `x::Trajectory` dispatch
# and give the test closures real state data to pull from.
function _lotka_trajectory_fc(p0, grid)
    prob = LotkaVolterra.generate()
    sol = solve(prob, Tsit5(); p = p0, saveat = grid)
    cache = Solutions.ControlSymbolCache(prob, Symbol[], [:L])
    seg = Solutions.ControlSegment(sol, cache)
    sseg = Solutions.ShootingSegment((seg,), cache)
    return Solutions.Trajectory((sseg,), cache)
end

traj = _lotka_trajectory_fc([1.0, 1.0, 0.3], [0.0, 6.0, 12.0])

function _make_container(foops...)
    layers = map(f -> DynamicFunctionLayer(f), foops)
    DynamicFunctions(Tuple(layers))
end

@testset "LuxCore.setup builds ps/st containers keyed by :functions" begin
    layer1 = DynamicFunctionLayer(
        (x, ps, st) -> (0.0, st); parameters = rng -> (; a = 1.0), state = rng -> (; called = false)
    )
    layer2 = DynamicFunctionLayer(
        (x, ps, st) -> (0.0, st); parameters = rng -> (; b = 2.0), state = rng -> (; called = true)
    )
    container = DynamicFunctions((layer1, layer2))

    ps, st = LuxCore.setup(rng, container)

    @test ps isa NamedTuple{(:functions,)}
    @test st isa NamedTuple{(:functions,)}
    @test ps.functions == ((; a = 1.0), (; b = 2.0))
    @test st.functions == ((; called = false), (; called = true))
end

@testset "out-of-place (x::Trajectory) concatenates each function's output" begin
    foop1 = (x, ps, st) -> (sum(x[:x]) * ps.scale, merge(st, (; called = true)))
    foop2 = (x, ps, st) -> ([sum(x[:y]), sum(x[:L])], merge(st, (; called = true)))

    layer1 = DynamicFunctionLayer(foop1; parameters = rng -> (; scale = 2.0))
    layer2 = DynamicFunctionLayer(foop2)
    container = DynamicFunctions((layer1, layer2))
    ps, st = LuxCore.setup(rng, container)

    out, st′ = container(traj, ps, st)

    expected = vcat(sum(traj[:x]) * ps.functions[1].scale, [sum(traj[:y]), sum(traj[:L])])
    @test out == expected
    @test st′.functions[1].called === true
    @test st′.functions[2].called === true
end

@testset "out-of-place with a single function behaves like that function alone" begin
    foop = (x, ps, st) -> (sum(x[:x]) - sum(x[:y]), st)
    container = _make_container(foop)
    ps, st = LuxCore.setup(rng, container)

    out, _ = container(traj, ps, st)

    @test out == sum(traj[:x]) - sum(traj[:y])
end

@testset "in-place (x::Tuple) writes each function's scalar result into the shared vector" begin
    fiip1 = (res, x, ps, st) -> begin
        res[1] = sum(x[:x])
        merge(st, (; called = true))
    end
    fiip2 = (res, x, ps, st) -> begin
        res[1] = sum(x[:y]) * ps.scale
        merge(st, (; called = true))
    end

    layer1 = DynamicFunctionLayer(nothing; isinplace = fiip1)
    layer2 = DynamicFunctionLayer(nothing; parameters = rng -> (; scale = 3.0), isinplace = fiip2)
    container = DynamicFunctions((layer1, layer2))
    ps, st = LuxCore.setup(rng, container)

    res = zeros(2)
    out, st′ = container((res, traj), ps, st)

    @test out === res
    @test res == [sum(traj[:x]), sum(traj[:y]) * 3.0]
    @test st′.functions[1].called === true
    @test st′.functions[2].called === true
end

@testset "in-place fallback (fiip === nothing) uses foop broadcast into the view" begin
    foop1 = (x, ps, st) -> (sum(x[:x]), st)
    foop2 = (x, ps, st) -> (sum(x[:y]) - sum(x[:L]), st)

    layer1 = DynamicFunctionLayer(foop1)
    layer2 = DynamicFunctionLayer(foop2)
    container = DynamicFunctions((layer1, layer2))
    ps, st = LuxCore.setup(rng, container)

    res = zeros(2)
    out, _ = container((res, traj), ps, st)

    @test out === res
    @test res == [sum(traj[:x]), sum(traj[:y]) - sum(traj[:L])]
end
