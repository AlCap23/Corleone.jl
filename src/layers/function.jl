"""
"""
@concrete terse struct DynamicFunctionLayer <: LuxCore.AbstractLuxLayer
    "Additional parameters"
    parameter
    "State constructor"
    state
    "Out of place function"
    foop 
    "Is in place function"
    fiip
end

function DynamicFunctionLayer(f; 
    parameters = (rng) -> (;), 
    state = (rng) -> (;),
    isinplace = nothing
    )
    DynamicFunctionLayer(parameters, state, f, isinplace)
end

LuxCore.initialparameters(rng::Random.AbstractRNG, layer::DynamicFunctionLayer) = layer.parameter(rng)
LuxCore.initialstates(rng::Random.AbstractRNG, layer::DynamicFunctionLayer) = layer.state(rng)

function (layer::DynamicFunctionLayer)(x::Trajectory, ps, st::NamedTuple)
    out, st = layer.foop(x, ps, st)
    out, st
end

function (layer::DynamicFunctionLayer)(res, x::Trajectory, ps, st::NamedTuple)
    st = layer.fiip(res, x, ps, st)
    res, st
end

function (layer::DynamicFunctionLayer{<:Any, <:Any, <:Any, Nothing})(res, x::Trajectory, ps, st::NamedTuple)
    _res, st = layer(x, ps, st)
    res .= _res
    res, st
end