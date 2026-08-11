"""
A layer that delegates to (a wrapper) or is built from (a container) other
`LuxCore.AbstractLuxLayer`s, as opposed to a true leaf layer.
"""
const NestedLayer = Union{LuxCore.AbstractLuxWrapperLayer, LuxCore.AbstractLuxContainerLayer}

"""
$(FUNCTIONNAME)(f, layer, ps, st)

Shared traversal combinator: applies `f(leaf, ps_leaf, st_leaf)` at every
`LuxCore.AbstractLuxLayer` leaf of `layer`, recursing through
`AbstractLuxWrapperLayer`, `AbstractLuxContainerLayer`, `NamedTuple`, and
`Tuple` nesting via `getproperty` (so `ps`/`st` may be a plain `NamedTuple`
or a `ComponentArrays.ComponentVector` — anything that supports property
access matching the layer tree's field names).

Wrapper layers forward their single leaf result unchanged; container layers
and `NamedTuple`s return a `NamedTuple` keyed by the same names as `T`/the
input; `Tuple`s return a `Tuple` in the same order.
"""
traverse_leaves(f, x::LuxCore.AbstractLuxLayer, ps, st) = f(x, ps, st)

traverse_leaves(f, x::LuxCore.AbstractLuxWrapperLayer{T}, ps, st) where {T} =
    traverse_leaves(f, getproperty(x, only(T)), ps, st)

traverse_leaves(f, x::Tuple, ps::Tuple, st::Tuple) =
    map((xi, psi, sti) -> traverse_leaves(f, xi, psi, sti), x, ps, st)

@generated function traverse_leaves(f, x::NamedTuple{NAMES}, ps, st) where {NAMES}
    rets = [gensym() for _ in NAMES]
    expr = Expr[]
    for (r, n) in zip(rets, NAMES)
        push!(expr, :($(r) = traverse_leaves(f, x.$(n), ps.$(n), st.$(n))))
    end
    push!(expr, :(return NamedTuple{NAMES}(($(rets...),))))
    return Expr(:block, expr...)
end

@generated function traverse_leaves(f, x::LuxCore.AbstractLuxContainerLayer{T}, ps, st) where {T}
    rets = [gensym() for _ in T]
    expr = Expr[]
    for (r, n) in zip(rets, T)
        push!(expr, :($(r) = traverse_leaves(f, x.$(n), ps.$(n), st.$(n))))
    end
    push!(expr, :(return NamedTuple{T}(($(rets...),))))
    return Expr(:block, expr...)
end

"""
$(FUNCTIONNAME)(x)

Recursively collects the non-`nothing` leaves of a (possibly nested)
`NamedTuple`/`Tuple` result of [`traverse_leaves`](@ref) into a flat
`Vector`, in traversal order. Leaves that are themselves arrays are kept
whole (not flattened element-by-element).
"""
flatten_leaves(::Nothing, acc = Any[]) = acc
function flatten_leaves(x::Union{NamedTuple, Tuple}, acc = Any[])
    foreach(v -> flatten_leaves(v, acc), x isa NamedTuple ? values(x) : x)
    return acc
end
flatten_leaves(x, acc = Any[]) = push!(acc, x)

"""
$(FUNCTIONNAME)(layer, ps, st)

Evaluate the continuity constraint contributed by `layer`.
"""
shooting_constraints(::LuxCore.AbstractLuxLayer, ps, st) = nothing
function shooting_constraints(x::NestedLayer, ps, st)
    return reduce(vcat, flatten_leaves(traverse_leaves(shooting_constraints, x, ps, st)); init = Float64[])
end

get_lower_bound(::T, val = -Inf) where {T <: Number} = T(val)
get_upper_bound(::T, val = Inf) where {T <: Number} = T(val)

for T in (NamedTuple, AbstractArray, Base.AbstractVecOrTuple)
    @eval get_lower_bound(x::$(T), val = -Inf) = map(Base.Fix2(get_lower_bound, val), x)
    @eval get_upper_bound(x::$(T), val = Inf) = map(Base.Fix2(get_upper_bound, val), x)
end

get_lower_bound(::LuxCore.AbstractLuxLayer, ps, st) = get_lower_bound(ps)
function get_lower_bound(x::NestedLayer, ps, st)
    return traverse_leaves(get_lower_bound, x, ps, st)
end

get_upper_bound(::LuxCore.AbstractLuxLayer, ps, st) = get_upper_bound(ps)
function get_upper_bound(x::NestedLayer, ps, st)
    return traverse_leaves(get_upper_bound, x, ps, st)
end

get_bounds(x::LuxCore.AbstractLuxLayer, ps, st) = (
    get_lower_bound(x, ps, st), get_upper_bound(x, ps, st),
)

function collect_activity_pattern(timepoints::AbstractVector, x::LuxCore.AbstractLuxLayer, ps, st)
    return ones(Bool, length(timepoints), LuxCore.parameterlength(x))
end

function collect_activity_pattern(timepoints::AbstractVector, x::NestedLayer, ps, st)
    return traverse_leaves(Base.Fix1(collect_activity_pattern, timepoints), x, ps, st)
end

function get_timepoints(x::LuxCore.AbstractLuxLayer, ps, st)
    return []
end

function get_timepoints(x::NestedLayer, ps, st)
    tpoints = reduce(vcat, flatten_leaves(traverse_leaves(get_timepoints, x, ps, st)); init = Float64[])
    return unique!(sort!(tpoints))
end
