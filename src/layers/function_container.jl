struct DynamicFunctions{N} <: LuxCore.AbstractLuxContainerLayer{(:functions,)}
    functions::NTuple{N, DynamicFunctionLayer}
end

function (f::DynamicFunctions)(x, ps, st)
    apply_functions(f, x, ps.functions, st.functions)
end

@generated function apply_functions(f::DynamicFunctions{N}, x::Solutions.Trajectory, ps, st) where N 
    exprs = Expr[]
    res = Symbol[]
    sts = Symbol[]
    
    for i in Base.OneTo(N)
        res_ = gensym(:res)
        st_ = gensym(:st)
        push!(res, res_)
        push!(sts, st_)
        push!(exprs, :(
            ($(res_), $(st_)) = f.functions[$(i)](x, ps[$(i)], st[$(i)])
        ))
    end

    push!(exprs, :(
        results = reduce(vcat, ($(res...),))
    ))

    push!(exprs, :(
        sts = (; functions = ($(sts...),),)
    ))
    push!(exprs, :(return (results, sts)))
    return Expr(:block, exprs...)
end

@generated function apply_functions(f::DynamicFunctions{N}, x::Tuple, ps, st) where N 
    exprs = Expr[]
    sts = Symbol[]
    
    for i in Base.OneTo(N)
        st_ = gensym(:st)
        push!(sts, st_)
        push!(exprs, :(
            (_, $(st_)) = f.functions[$(i)](view(x[1], $(i:i)), x[2], ps[$(i)], st[$(i)])
        ))
    end

    push!(exprs, :(
        sts = (; functions = ($(sts...),),)
    ))
    push!(exprs, :(return (x[1], sts)))
    return Expr(:block, exprs...)
end

