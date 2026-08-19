module Parser

using SymbolicIndexingInterface
using TermInterface
using DocStringExtensions

struct Parser{S, V, P, I}
    sys::S
    variables::V
    parameters::P
    indexgrid::I
end

maybeunwrap(x) = iscall(x) ? operation(x) : x

function Parser{T}(sys) where {T <: Real}
    variables = Dict{eltype(variable_symbols(sys)), Vector{T}}()
    foreach(variable_symbols(sys)) do v
        variables[maybeunwrap(v)] = T[]
    end
    parameters = Set{eltype(parameter_symbols(sys))}()
    return Parser(sys, variables, parameters, Dict{T, Int64}())
end

Parser(sys) = Parser{Float64}(sys)

function Base.empty!(parser::Parser)
    (; variables, parameters, indexgrid) = parser
    foreach(keys(variables)) do v
        empty!(variables[v])
    end
    empty!(parameters)
    empty!(indexgrid)
    return parser
end

get_value(x) = x
# TODO: re-enable once ModelingToolkit support lands (comment on
# 2026-08-19: leaving unsupported for now, will be added in a future commit)
# get_value(x::ModelingToolkit.SymbolicUtils.BasicSymbolic) = x.val

function collect_leafs!(parser::Parser, term)
    (; sys, variables, parameters) = parser
    @info term
    if !iscall(term)
        if any(Base.Fix1(isequal, term), parameter_symbols(sys))
            push!(parameters, term)
        end
        return parser
    end
    op = operation(term)
    args = arguments(term)
    @info op args
    if any(Base.Fix1(isequal, op), keys(variables))
        push!(variables[op], (get_value ∘ only)(args))
    else
        foreach(args) do arg
            collect_leafs!(parser, arg)
        end
    end
    return parser
end

function generate_grid!(parser::Parser, timepoints)
    (; indexgrid, variables) = parser
    tpoints = reduce(vcat, values(variables))
    append!(tpoints, timepoints)
    unique!(tpoints)
    sort!(tpoints)
    for (i, t) in enumerate(tpoints)
        indexgrid[t] = i
    end
    return parser
end

function replace_variables(parser::Parser, term)
    (; variables, indexgrid) = parser
    !iscall(term) && return term
    op = operation(term)
    args = arguments(term)
    if any(Base.Fix1(isequal, op), keys(variables))
        return Expr(:call, getindex, op, indexgrid[(get_value ∘ only)(args)])
    end
    newargs = map(args) do x
        replace_variables(parser, x)
    end
    return Expr(:call, op, newargs...)
end

function generate_getter(parser::Parser, x = gensym(:trajectory))
    (; variables, parameters) = parser
    exprs = Expr[]
    for v in keys(variables)
        t = variables[v]
        if !isempty(t)
            getter = Expr(:call, :getindex, x, QuoteNode(v))
            push!(exprs, :($(v) = $(getter)))
        end
    end
    for p in parameters
        getter = Expr(:call, :getindex, Expr(:call, :getproperty, x, QuoteNode(:ps)), QuoteNode(p))
        push!(exprs, :($(p) = $(getter)))
    end
    return exprs
end

function generate_function(parser::Parser, term)
    body = Expr[]
    arg = gensym(:trajectory)
    append!(body, generate_getter(parser, arg))
    push!(body, replace_variables(parser, term))
    oop_signature = Expr(:call, gensym(:f), arg, :ps, :st)
    expr_oop = Expr(:function, oop_signature, Expr(:block, body...))
    res = gensym(:res)
    push!(body, :($(res)[1] = $(last(body))))
    iip_signature = Expr(:call, gensym(:f), res, arg, :ps, :st)
    expr_iip = Expr(:function, iip_signature, Expr(:block, body...))
    return expr_oop, expr_iip
end

function (parser::Parser)(terms...; timepoints = [])
    empty!(parser)
    foreach(terms) do term
        collect_leafs!(parser, term)
    end
    generate_grid!(parser, timepoints)
    return map(terms) do term
        generate_function(parser, term)
    end
end

export Parser

end
