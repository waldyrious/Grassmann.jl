
#   This file is part of Grassmann.jl. It is licensed under the GPL license
#   Grassmann Copyright (C) 2019 Michael Reed

import Base: @pure, print, show, getindex, setindex!, promote_rule, ==, convert, ndims
import DirectSum: Bits, bit2int, doc2m, indexbits, indices, diffvars, Dim, diffmask, symmetricmask, indexstring, indexsymbol, norm

bcast(op,arg) = op ∈ (:(DirectSum.:∑),:(DirectSum.:-)) ? Expr(:.,op,arg) : Expr(:call,op,arg.args...)

@pure promote_type(t...) = Base.promote_type(t...)
@pure binomial_set(N) = SVector(Int[binomial(N,g) for g ∈ 0:N]...)
@pure binomial(N,G) = Base.binomial(N,G)
@pure mvec(N,G,t) = MVector{binomial(N,G),t}
@pure mvec(N,t) = MVector{2^N,t}
@pure svec(N,G,t) = SizedArray{Tuple{binomial(N,G)},t,1,1}
@pure svec(N,t) = SizedArray{Tuple{1<<N},t,1,1}
@pure intlog(M::Integer) = Int(log2(M))

## constructor

@inline assign_expr!(e,x::Vector{Any},v::Symbol,expr) = v ∈ e && push!(x,Expr(:(=),v,expr))

@pure function insert_expr(e,vec=:mvec,T=:(valuetype(a)),S=:(valuetype(b)),L=:(2^N);mv=0)
    x = Any[] # Any[:(sigcheck(sig(a),sig(b)))]
    assign_expr!(e,x,:N,:(ndims(V)))
    assign_expr!(e,x,:M,:(Int(N/2)))
    assign_expr!(e,x,:t,vec≠:mvec ? :Any : :(promote_type($T,$S)))
    assign_expr!(e,x,:out,mv≠0 ? :(t=Any;convert(svec(N,Any),out)) : :(zeros($vec(N,t))))
    assign_expr!(e,x,:r,:(binomsum(N,G)))
    assign_expr!(e,x,:bng,:(binomial(N,G)))
    assign_expr!(e,x,:bnl,:(binomial(N,L)))
    assign_expr!(e,x,:ib,:(indexbasis(N,G)))
    assign_expr!(e,x,:bs,:(binomsum_set(N)))
    assign_expr!(e,x,:bn,:(binomial_set(N)))
    assign_expr!(e,x,:df,:(dualform(V)))
    assign_expr!(e,x,:di,:(dualindex(V)))
    assign_expr!(e,x,:D,:(diffvars(V)))
    assign_expr!(e,x,:μ,:(diffvars(V)≠0))
    assign_expr!(e,x,:P,:(hasinf(V)+hasorigin(V)))
    return x
end

## cache

const algebra_limit = 8
const sparse_limit = 22
const cache_limit = 12
const fill_limit = 0.5

const binomsum_cache = [[0],[0,1]]
const binomsum_extra = Vector{Int}[]
@pure function binomsum(n::Int, i::Int)::Int
    if n>sparse_limit
        N=n-sparse_limit
        for k ∈ length(binomsum_extra)+1:N
            push!(binomsum_extra,Int[])
        end
        @inbounds isempty(binomsum_extra[N]) && (binomsum_extra[N]=[0;cumsum([binomial(n,q) for q=0:n])])
        @inbounds binomsum_extra[N][i+1]
    else
        for k=length(binomsum_cache):n+1
            push!(binomsum_cache, [0;cumsum([binomial(k,q) for q=0:k])])
        end
        @inbounds binomsum_cache[n+1][i+1]
    end
end
@pure function binomsum_set(n::Int)::Vector{Int}
    if n>sparse_limit
        N=n-sparse_limit
        for k ∈ length(binomsum_extra)+1:N
            push!(binomsum_extra,Int[])
        end
        @inbounds isempty(binomsum_extra[N]) && (binomsum_extra[N]=[0;cumsum([binomial(n,q) for q=0:n])])
        @inbounds binomsum_extra[N]
    else
        for k=length(binomsum_cache):n+1
            push!(binomsum_cache, [0;cumsum([binomial(k,q) for q=0:k])])
        end
        @inbounds binomsum_cache[n+1]
    end
end

const combo_cache = Vector{Vector{Vector{Int}}}[]
const combo_extra = Vector{Vector{Vector{Int}}}[]
function combo(n::Int,g::Int)::Vector{Vector{Int}}
    if g == 0
        [Int[]]
    elseif n>sparse_limit
        N=n-sparse_limit
        for k ∈ length(combo_extra)+1:N
            push!(combo_extra,Vector{Vector{Int}}[])
        end
        @inbounds for k ∈ length(combo_extra[N])+1:g
            @inbounds push!(combo_extra[N],Vector{Int}[])
        end
        @inbounds isempty(combo_extra[N][g]) && (combo_extra[N][g]=collect(combinations(1:n,g)))
        @inbounds combo_extra[N][g]
    else
        for k ∈ length(combo_cache)+1:min(n,sparse_limit)
            z = 1:k
            push!(combo_cache,[collect(combinations(z,q)) for q ∈ z])
        end
        @inbounds combo_cache[n][g]
    end
end

@pure function bladeindex_calc(d,k)
    H = indices(UInt(d),k)
    findall(x->x==H,combo(k,length(H)))[1]
end
const bladeindex_cache = Vector{Int}[]
const bladeindex_extra = Vector{Int}[]
@pure function bladeindex(n::Int,s::Bits)::Int
    if s == 0
        1
    elseif n>(DirectSum.index_limit)
        bladeindex_calc(s,n)
    elseif n>cache_limit
        N = n-cache_limit
        for k ∈ length(bladeindex_extra)+1:N
            push!(bladeindex_extra,Int[])
        end
        @inbounds isempty(bladeindex_extra[N]) && (bladeindex_extra[N]=-ones(Int,1<<n-1))
        @inbounds signbit(bladeindex_extra[N][s]) && (bladeindex_extra[N][s]=bladeindex_calc(s,n))
        @inbounds bladeindex_extra[N][s]
    else
        j = length(bladeindex_cache)+1
        for k ∈ j:min(n,cache_limit)
            push!(bladeindex_cache,[bladeindex_calc(d,k) for d ∈ 1:1<<k-1])
            GC.gc()
        end
        @inbounds bladeindex_cache[n][s]
    end
end

@inline basisindex_calc(d,k) = binomsum(k,count_ones(UInt(d)))+bladeindex(k,UInt(d))
const basisindex_cache = Vector{Int}[]
const basisindex_extra = Vector{Int}[]
@pure function basisindex(n::Int,s::Bits)::Int
    if s == 0
        1
    elseif n>(DirectSum.index_limit)
        basisindex_calc(s,n)
    elseif n>cache_limit
        N = n-cache_limit
        for k ∈ length(basisindex_extra)+1:N
            push!(basisindex_extra,Int[])
        end
        @inbounds isempty(basisindex_extra[N]) && (basisindex_extra[N]=-ones(Int,1<<n-1))
        @inbounds signbit(basisindex_extra[N][s]) && (basisindex_extra[N][s]=basisindex_calc(s,n))
        @inbounds basisindex_extra[N][s]
    else
        j = length(basisindex_cache)+1
        for k ∈ j:min(n,cache_limit)
            push!(basisindex_cache,[basisindex_calc(d,k) for d ∈ 1:1<<k-1])
            GC.gc()
        end
        @inbounds basisindex_cache[n][s]
    end
end

const indexbasis_cache = Vector{Vector{UInt}}[]
const indexbasis_extra = Vector{Vector{UInt}}[]
@pure function indexbasis(n::Int,g::Int)::Vector{UInt}
    if n>sparse_limit
        N = n-sparse_limit
        for k ∈ length(indexbasis_extra)+1:N
            push!(indexbasis_extra,Vector{UInt}[])
        end
        @inbounds for k ∈ length(indexbasis_extra[N])+1:g
            @inbounds push!(indexbasis_extra[N],UInt[])
        end
        @inbounds if isempty(indexbasis_extra[N][g])
            @inbounds indexbasis_extra[N][g] = [bit2int(indexbits(n,combo(n,g)[q])) for q ∈ 1:binomial(n,g)]
        end
        @inbounds indexbasis_extra[N][g]
    else
        for k ∈ length(indexbasis_cache)+1:n
            push!(indexbasis_cache,[[bit2int(indexbits(k,@inbounds(combo(k,G)[q]))) for q ∈ 1:binomial(k,G)] for G ∈ 1:k])
        end
        @inbounds g>0 ? indexbasis_cache[n][g] : [zero(UInt)]
    end
end
@pure indexbasis(N) = vcat(indexbasis(N,0),indexbasis_set(N)...)
@pure indexbasis_set(N) = SVector(((N≠0 && N<sparse_limit) ? @inbounds(indexbasis_cache[N]) : Vector{Bits}[indexbasis(N,g) for g ∈ 0:N])...)

bladeindex(cache_limit,one(Bits))
basisindex(cache_limit,one(Bits))
indexbasis(Int((sparse_limit+cache_limit)/2),1)

# SubManifold

const lowerbits_cache = Vector{Vector{UInt}}[]
const lowerbits_extra = Dict{UInt,Dict{UInt,UInt}}[]
@pure lowerbits_calc(N,S,B,k=indices(S,N)) = bit2int(indexbits(N,findall(x->x∈k,indices(B,N))))
@pure function lowerbits(N,S,B)
    if N>cache_limit
        n = N-cache_limit
        for k ∈ length(lowerbits_extra)+1:n
            push!(lowerbits_extra,Dict{UInt,Dict{UInt,UInt}}())
        end
        @inbounds !haskey(lowerbits_extra[n],S) && push!(lowerbits_extra[n],S=>Dict{UInt,UInt}())
        @inbounds !haskey(lowerbits_extra[n][S],B) && push!(lowerbits_extra[n][S],B=>lowerbits_calc(N,S,B))
        @inbounds lowerbits_extra[n][S][B]
    else
        for k ∈ length(lowerbits_cache)+1:min(N,cache_limit)
            push!(lowerbits_cache,Vector{Int}[])
        end
        for s ∈ length(lowerbits_cache[N])+1:S
            k = indices(S,N)
            push!(lowerbits_cache[N],[lowerbits_calc(N,s,d,k) for d ∈ UInt(0):UInt(1)<<(N+1)-1])
        end
        @inbounds lowerbits_cache[N][S][B+1]
    end
end

const expandbits_cache = Dict{UInt,Dict{UInt,UInt}}[]
@pure expandbits_calc(N,S,B) = bit2int(indexbits(N,indices(S,N)[indices(B,N)]))
@pure function expandbits(N,S,B)
    for k ∈ length(expandbits_cache)+1:N
        push!(expandbits_cache,Dict{UInt,Dict{UInt,UInt}}())
    end
    @inbounds !haskey(expandbits_cache[N],S) && push!(expandbits_cache[N],S=>Dict{UInt,UInt}())
    @inbounds !haskey(expandbits_cache[N][S],B) && push!(expandbits_cache[N][S],B=>expandbits_calc(N,S,B))
    @inbounds expandbits_cache[N][S][B]
end

#=const expandbits_cache = Vector{Vector{UInt}}[]
const expandbits_extra = Dict{UInt,Dict{UInt,UInt}}[]
@pure expandbits_calc(N,S,B,k=indices(S,N)) = bit2int(indexbits(N,k[indices(B,N)]))
@pure function expandbits(N,S,B)
    if N>cache_limit
        n = N-cache_limit
        for k ∈ length(expandbits_extra)+1:n
            push!(expandbits_extra,Dict{UInt,Dict{UInt,UInt}}())
        end
        @inbounds !haskey(expandbits_extra[n],S) && push!(expandbits_extra[n],S=>Dict{UInt,UInt}())
        @inbounds !haskey(expandbits_extra[n][S],B) && push!(expandbits_extra[n][S],B=>expandbits_calc(N,S,B))
        @inbounds expandbits_extra[n][S][B]
    else
        for k ∈ length(expandbits_cache)+1:min(N,cache_limit)
            push!(expandbits_cache,Vector{Int}[])
        end
        for s ∈ length(expandbits_cache[N])+1:S
            k = indices(S,N)
            push!(expandbits_cache[N],[expandbits_calc(N,s,d,k) for d ∈ UInt(0):UInt(1)<<(N+1)-1])
        end
        @inbounds expandbits_cache[N][S][B+1]
    end
end=#


