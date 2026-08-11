@generated function nested_eval(f, x, ps, st::NamedTuple{NAMES}) where {NAMES}
    rets = [gensym() for _ in NAMES]
    expr = Expr[]
    for (r, n) in zip(rets, NAMES)
        push!(expr, :($(r) = f(x.$(n), ps.$(n), st.$(n))))
    end
    push!(expr, :(return NamedTuple{NAMES}(($(rets...),))))
    return Expr(:block, expr...)
end

"""
$(FUNCTIONNAME)(layer, ps, st)

Evaluate the continuity constraint contributed by `layer`.
"""
shooting_constraints(::LuxCore.AbstractLuxLayer, ps, st) = nothing
shooting_constraints(x::LuxCore.AbstractLuxWrapperLayer{T}, ps, st) where {T} = shooting_constraints(getproperty(x, only(T)), ps, st)
shooting_constraints(x::LuxCore.AbstractLuxContainerLayer{T}, ps, st) where {T} = reduce(
    vcat, map(T) do ti
        getter = Base.Fix2(getproperty, ti)
        nested_eval(shooting_constraints, getter(x), getter(ps), getter(st))
    end
)

get_lower_bound(::T, val = -Inf) where {T <: Number} = T(val)
get_upper_bound(::T, val = Inf) where {T <: Number} = T(val)

for T in (NamedTuple, AbstractArray, Base.AbstractVecOrTuple)
    @eval get_lower_bound(x::$(T), val = -Inf) = map(Base.Fix2(get_lower_bound, val), x)
    @eval get_upper_bound(x::$(T), val = Inf) = map(Base.Fix2(get_upper_bound, val), x)
end

get_lower_bound(::LuxCore.AbstractLuxLayer, ps, st) = get_lower_bound(ps)
get_lower_bound(x::LuxCore.AbstractLuxWrapperLayer{T}, ps, st) where {T} = get_lower_bound(getproperty(x, only(T)), ps, st)
function get_lower_bound(x::LuxCore.AbstractLuxContainerLayer{T}, ps, st) where {T}
    return map(T) do name
        getter = Base.Fix2(getproperty, name)
        nested_eval(get_lower_bound, getter(x), getter(ps), getter(st))
    end
end

get_upper_bound(::LuxCore.AbstractLuxLayer, ps, st) = get_upper_bound(ps)
get_upper_bound(x::LuxCore.AbstractLuxWrapperLayer{T}, ps, st) where {T} = get_upper_bound(getproperty(x, only(T)), ps, st)
function get_upper_bound(x::LuxCore.AbstractLuxContainerLayer{T}, ps, st) where {T}
    return map(T) do name
        getter = Base.Fix2(getproperty, name)
        nested_eval(get_upper_bound, getter(x), getter(ps), getter(st))
    end
end

get_bounds(x::LuxCore.AbstractLuxLayer, ps, st) = (
    get_lower_bound(x, ps, st), get_upper_bound(x, ps, st),
)

function collect_activity_pattern(timepoints::AbstractVector, x::LuxCore.AbstractLuxLayer, ps, st)
    return ones(Bool, length(timepoints), LuxCore.parameterlength(x))
end

function collect_activity_pattern(timepoints::AbstractVector, x::LuxCore.AbstractLuxWrapperLayer{T}, ps, st) where {T}
    return collect_activity_pattern(timepoints, getproperty(x, only(T)), ps, st)
end

function collect_activity_pattern(timepoints::AbstractVector, x::LuxCore.AbstractLuxContainerLayer{T}, ps, st) where {T}
    return map(T) do ti
        getter = Base.Fix2(getproperty, ti)
        ti => nested_eval((x...) -> collect_activity_pattern(timepoints, x...), getter(x), getter(ps), getter(st))
    end |> NamedTuple
end


function get_timepoints(x::LuxCore.AbstractLuxLayer, ps, st)
    return []
end

function get_timepoints(x::LuxCore.AbstractLuxWrapperLayer{T}, ps, st) where {T}
    return get_timepoints(getproperty(x, only(T)), ps, st)
end

function get_timepoints(x::NamedTuple{NAMES}, ps, st) where {NAMES}
    return reduce(
        vcat, map(NAMES) do key
            get_timepoints(getproperty(x, key), getproperty(ps, key), getproperty(st, key))
        end
    )
end

function get_timepoints(x::Tuple, ps::Tuple, st::Tuple)
    return reduce(
        vcat, map(zip(x, ps, st)) do (xi, psi, sti)
            get_timepoints(xi, psi, sti)
        end
    )
end

function get_timepoints(x::LuxCore.AbstractLuxContainerLayer{T}, ps, st) where {T}
    tpoints = reduce(
        vcat, map(T) do ti
            getter = Base.Fix2(getproperty, ti)
            container = getter(x)
            ps_i = getter(ps)
            st_i = getter(st)
            get_timepoints(container, ps_i, st_i)
        end
    )
    return unique!(sort!(tpoints))
end
