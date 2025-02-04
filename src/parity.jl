
#   This file is part of Grassmann.jl. It is licensed under the GPL license
#   Grassmann Copyright (C) 2019 Michael Reed

@pure function parityjoin(N,S,a,b)
    B = DirectSum.digits_fast(b<<1,N)
    isodd(sum(DirectSum.digits_fast(a,N) .* cumsum(B))+count_ones((a & b) & S))
end

## adjoint parities

@pure parityreverse(G) = isodd(Int((G-1)*G/2))
@pure parityinvolute(G) = isodd(G)
@pure parityconj(G) = parityreverse(G)⊻parityinvolute(G)

## complement parity

@pure parityrighthodge(V::Int,B,G,N=nothing) = isodd(V)⊻parityright(V,B,G,N)
@pure paritylefthodge(V::Int,B,G,N) = (isodd(G) && iseven(N)) ⊻ parityrightgrade(V,B,G,N)
@pure parityright(V::Int,B,G,N=nothing) = isodd(B+Int((G+1)*G/2))
@pure parityleft(V::Int,B,G,N) = (isodd(G) && iseven(N)) ⊻ parityright(V,B,G,N)

for side ∈ (:left,:right)
    p = Symbol(:parity,side)
    pg = Symbol(p,:hodge)
    pn = Symbol(p,:null)
    pnp = Symbol(pn,:pre)
    @eval begin
        @pure $p(V::Bits,B::Bits,N::Int) = $p(0,sum(indices(B,N)),count_ones(B),N)
        @pure $pg(V::Bits,B::Bits,N::Int) = $pg(count_ones(V&B),sum(indices(B,N)),count_ones(B),N)
        @inline $pn(V,B,v) = v
        @inline function $pn(V::Signature,B,v)
            hi,ho = hasinf(V),hasorigin(V)
            if hi && ho && count_ones(B&UInt(3)) ==1
                isodd(B) ? (2v) : (v/2)
            else
                v
            end
        end
        @inline $pnp(V,B,v) = v
        @inline function $pnp(V::Signature,B,v)
            hi,ho = hasinf(V),hasorigin(V)
            if hi && ho && count_ones(B&UInt(3)) ==1
                isodd(B) ? Expr(:call,:*,2,v) : Expr(:call,:/,v,2)
            else
                v
            end
        end
        @pure function $p(V::Signature,B,G=count_ones(B))
            b = B&(UInt(1)<<(ndims(V)-diffvars(V))-1)
            $p(0,sum(indices(b,ndims(V))),count_ones(b),ndims(V)-diffvars(V))
        end
        @pure function $pg(V::Signature,B,G=count_ones(B))
            o = hasorigin(V) && hasinf(V) && (iszero(B&UInt(1))&(!iszero(B&UInt(2))))
            b = B&(UInt(1)<<(ndims(V)-diffvars(V))-1)
            $pg(count_ones(value(V)&b),sum(indices(b,ndims(V))),count_ones(b),ndims(V)-diffvars(V))⊻o
        end
        @pure function $p(V::DiagonalForm,B,G=count_ones(B))
            ind = indices(B&(UInt(1)<<(ndims(V)-diffvars(V))-1),ndims(V))
            $p(0,sum(ind),G,ndims(V)-diffvars(V)) ? -1 : 1
        end
        @pure function $pg(V::DiagonalForm,B,G=count_ones(B))
            ind = indices(B&(UInt(1)<<(ndims(V)-diffvars(V))-1),ndims(V))
            g = prod(V[ind])
            $p(0,sum(ind),G,ndims(V)-diffvars(V)) ? -(g) : g
        end
    end
    for p ∈ (p,pg)
        @eval begin
            @pure $p(b::Basis{V,G,B}) where {V,G,B} = $p(V,B,G)
        end
    end
end

@pure function complement(N::Int,B::UInt,D::Int=0,P::Int=0)::UInt
    UP,ND = UInt(1)<<(P==1 ? 0 : P)-1, N-D
    C = ((~B)&(UP⊻(UInt(1)<<ND-1)))|(B&(UP⊻((UInt(1)<<D-1)<<ND)))
    count_ones(C&UP)≠1 ? C⊻UP : C
end

## product parities

@pure conformalmask(V::M) where M<:Manifold = UInt(2)^(hasinf(V)&&hasorigin(V) ? 2 : 0)-1

@pure function conformalcheck(V::M,A,B) where M<:Manifold
    bt = conformalmask(V)
    i2o,o2i = DirectSum.hasinf2origin(V,A,B),DirectSum.hasorigin2inf(V,A,B)
    A&bt, B&bt, i2o, o2i, i2o ⊻ o2i
end

@pure function parityconformal(V::M,A,B) where M<:Manifold
    C,hio = A ⊻ B, hasinforigin(V,A,B)
    cc = hio || hasorigininf(V,A,B)
    A3,B3,i2o,o2i,xor = conformalcheck(V,A,B)
    pcc,bas = xor⊻i2o⊻(i2o&o2i), xor ? (A3|B3)⊻C : C
    return pcc, bas, cc, zero(UInt)
end

@pure function parityregressive(V::Signature{N,M,S},a,b,::Val{skew}=Val{false}()) where {N,M,S,skew}
    D = diffvars(V)
    (A,B,Q,Z),NG = symmetricmask(V,a,b),N-D
    α,β = complement(N,A,D),complement(N,B,D)
    cc = skew && (hasinforigin(V,A,β) || hasorigininf(V,A,β))
    if ((count_ones(α&β)==0) && !diffcheck(V,α,β)) || cc
        C,L = α ⊻ β, count_ones(A)+count_ones(B)
        pcc,bas = if skew
            A3,β3,i2o,o2i,xor = conformalcheck(V,A,β)
            cx,bas = cc || xor, complement(N,C,D)
            cx && parity(A3,β3,V)⊻(i2o || o2i)⊻(xor&!i2o), cx ? (A3|β3)⊻bas : bas
        else
            false, A+B≠0 ? complement(N,C,D) : g_zero(UInt)
        end
        par = parityrighthodge(S,A,N)⊻parityrighthodge(S,B,N)⊻parityrighthodge(S,C,N)
        return (isodd(L*(L-grade(V)))⊻par⊻parity(N,S,α,β)⊻pcc)::Bool, bas|Q, true, Z
    else
        return false, g_zero(UInt), false, Z
    end
end

@pure function parityregressive(V::M,A,B) where M<:Manifold
    p,C,t,Z = regressive(A,B,Signature(V))
    return p ? -1 : 1, C, t, Z
end

@pure function parityinterior(V::Signature{N,M,S},a,b) where {N,M,S}
    A,B,Q,Z = symmetricmask(V,a,b)
    diffcheck(V,A,B) && (return false,g_zero(UInt),false,Z)
    γ = complement(N,B,diffvars(V))
    p,C,t = parityregressive(V,A,γ,Val{true}())
    return t ? p⊻parityrighthodge(S,B,N) : p, C|Q, t, Z
end

@pure function parityinterior(V::M,a,b) where M<:Manifold{N} where N
    A,B,Q,Z = symmetricmask(V,a,b)
    diffcheck(V,A,B) && (return false,g_zero(UInt),false,Z)
    γ = complement(N,B,diffvars(V))
    p,C,t = parityregressive(Signature(V),A,γ,Val{true}())
    ind = indices(B,N)
    g = prod(V[ind])
    return t ? (p⊻parityright(0,sum(ind),count_ones(B)) ? -(g) : g) : g, C|Q, t, Z
end

@pure function parityinner(a::Bits,b::Bits,V::M) where M<:Manifold
    A,B = symmetricmask(V,a,b)
    g = abs(prod(V[indices(A&B,ndims(V))]))
    parity(A,B,Signature(V)) ? -(g) : g
end

@pure function paritycrossprod(V::Signature{N,M,S},a,b) where {N,M,S}
    A,B,Q,Z = symmetricmask(V,a,b)
    if (count_ones(A&B)==0) && !(hasinf(M) && isodd(A) && isodd(B))
        C = A ⊻ B
        return (parity(N,S,A,B)⊻parityrighthodge(S,C,N)), complement(N,C,diffvars(V))|Q, true, Z
    else
        return false, zero(Bits), false, Z
    end
end

@pure function paritycrossprod(V::M,a,b) where M<:Manifold{N} where N
    A,B,Q,Z = symmetricmask(V,a,b)
    if (count_ones(A&B)==0) && !(hasinf(V) && isodd(A) && isodd(B))
        C = A ⊻ B
        g = parityrighthodge(V,C,N)
        return parity(A,B,V) ? -(g) : g, complement(N,C,diffvars(V))|Q, true, Z
    else
        return 1, zero(Bits), false, Z
    end
end

### parity cache

const parity_cache = Dict{Bits,Vector{Vector{Bool}}}[]
const parity_extra = Dict{Bits,Dict{Bits,Dict{Bits,Bool}}}[]
@pure function parity(n,s,a,b)::Bool
    if n > sparse_limit
        N = n-sparse_limit
        for k ∈ length(parity_extra)+1:N
            push!(parity_extra,Dict{Bits,Dict{Bits,Dict{Bits,Bool}}}())
        end
        @inbounds !haskey(parity_extra[N],s) && push!(parity_extra[N],s=>Dict{Bits,Dict{Bits,Bool}}())
        @inbounds !haskey(parity_extra[N][s],a) && push!(parity_extra[N][s],a=>Dict{Bits,Bool}())
        @inbounds !haskey(parity_extra[N][s][a],b) && push!(parity_extra[N][s][a],b=>parityjoin(n,s,a,b))
        @inbounds parity_extra[N][s][a][b]
    else
        a1 = a+1
        for k ∈ length(parity_cache)+1:n
            push!(parity_cache,Dict{Bits,Vector{Bool}}())
        end
        @inbounds !haskey(parity_cache[n],s) && push!(parity_cache[n],s=>Vector{Bool}[])
        @inbounds for k ∈ length(parity_cache[n][s]):a
            @inbounds push!(parity_cache[n][s],Bool[])
        end
        @inbounds for k ∈ length(parity_cache[n][s][a1]):b
            @inbounds push!(parity_cache[n][s][a1],parityjoin(n,s,a,k))
        end
        @inbounds parity_cache[n][s][a1][b+1]
    end
end
@pure function parity(a::Bits,b::Bits,v::Signature)
    d=diffmask(v)
    D=mixedmode(v)<0 ? |(d...) : d
    parity(ndims(v),value(v),(a&~D),(b&~D))
end
@pure parity(a::Bits,b::Bits,v::Manifold) = parity(a,b,Signature(v))
@pure parity(a::Basis{V,G,B},b::Basis{V,L,C}) where {V,G,B,L,C} = parity(bits(a),bits(b),V)

### parity product caches

for par ∈ (:conformal,:regressive,:interior,:crossprod)
    calc = Symbol(:parity,par)
    for (vs,space,dat) ∈ ((:_sig,Signature,Bool),(:_diag,DiagonalForm,Any))
        T = Tuple{dat,Bits,Bool,Bits}
        extra = Symbol(par,vs,:_extra)
        cache = Symbol(par,vs,:_cache)
        @eval begin
            const $cache = Vector{Dict{Bits,Vector{Vector{$T}}}}[]
            const $extra = Vector{Dict{Bits,Dict{Bits,Dict{Bits,$T}}}}[]
            @pure function ($par(a,b,V::W)::$T) where W<:$space{n,m,s} where {n,m,s}
                m1 = m+1
                if n > sparse_limit
                    N = n-sparse_limit
                    for k ∈ length($extra)+1:N
                        push!($extra,Dict{Bits,Dict{Bits,Dict{Bits,$T}}}[])
                    end
                    for k ∈ length($extra[N])+1:m1
                        @inbounds push!($extra[N],Dict{Bits,Dict{Bits,Dict{Bits,$T}}}())
                    end
                    @inbounds !haskey($extra[N][m1],s) && push!($extra[N][m1],s=>Dict{Bits,Dict{Bits,$T}}())
                    @inbounds !haskey($extra[N][m1][s],a) && push!($extra[N][m1][s],a=>Dict{Bits,$T}())
                    @inbounds !haskey($extra[N][m1][s][a],b) && push!($extra[N][m1][s][a],b=>$calc(V,a,b))
                    @inbounds $extra[N][m1][s][a][b]
                else
                    a1 = a+1
                    for k ∈ length($cache)+1:n
                        push!($cache,Dict{Bits,Vector{Vector{$T}}}[])
                    end
                    @inbounds for k ∈ length($cache[n])+1:m1
                        @inbounds push!($cache[n],Dict{Bits,Vector{Vector{$T}}}())
                    end
                    @inbounds !haskey($cache[n][m1],s) && push!($cache[n][m1],s=>Vector{$T}[])
                    @inbounds for k ∈ length($cache[n][m1][s]):a
                        @inbounds push!($cache[n][m1][s],$T[])
                    end
                    @inbounds for k ∈ length($cache[n][m1][s][a1]):b
                        @inbounds push!($cache[n][m1][s][a1],$calc(V,a,k))
                    end
                    @inbounds $cache[n][m1][s][a1][b+1]
                end
            end
        end
    end
    for (vs,space,dat) ∈ ((:_sub,SubManifold,Any),)
        T = Tuple{dat,Bits,Bool}
        extra = Symbol(par,vs,:_extra)
        cache = Symbol(par,vs,:_cache)
        @eval begin
            const $cache = Dict{Bits,Vector{Dict{Bits,Vector{Vector{$T}}}}}[]
            const $extra = Dict{Bits,Vector{Dict{Bits,Dict{Bits,Dict{Bits,$T}}}}}[]
            @pure function ($par(a,b,V::W)::$T) where W<:$space{NN,M,s} where {NN,M,s}
                n,m,S = ndims(M),DirectSum.options(M),value(M)
                m1 = m+1
                if n > sparse_limit
                    N = n-sparse_limit
                    for k ∈ length($extra)+1:N
                        push!($extra,Dict{Bits,Vector{Dict{Bits,Dict{Bits,Dict{Bits,$T}}}}}())
                    end
                    if !haskey($extra[N],S)
                        push!($extra[N],S=>Dict{Bits,Dict{Bits,Dict{Bits,$T}}}[])
                    end
                    for k ∈ length($extra[N][S])+1:m1
                        @inbounds push!($extra[N][S],Dict{Bits,Dict{Bits,Dict{Bits,$T}}}())
                    end
                    @inbounds !haskey($extra[N][S][m1],s) && push!($extra[N][S][m1],s=>Dict{Bits,Dict{Bits,$T}}())
                    @inbounds !haskey($extra[N][S][m1][s],a) && push!($extra[N][S][m1][s],a=>Dict{Bits,$T}())
                    @inbounds !haskey($extra[N][S][m1][s][a],b) && push!($extra[N][S][m1][s][a],b=>$calc(V,a,b))
                    @inbounds $extra[N][S][m1][s][a][b]
                else
                    a1 = a+1
                    for k ∈ length($cache)+1:n
                        push!($cache,Dict{Bits,Dict{Bits,Vector{Vector{$T}}}}())
                    end
                    if !haskey($cache[n],S)
                        push!($cache[n],S=>Dict{Bits,Vector{Vector{$T}}}[])
                    end
                    @inbounds for k ∈ length($cache[n][S])+1:m1
                        @inbounds push!($cache[n][S],Dict{Bits,Vector{Vector{$T}}}())
                    end
                    @inbounds !haskey($cache[n][S][m1],s) && push!($cache[n][S][m1],s=>Vector{$T}[])
                    @inbounds for k ∈ length($cache[n][S][m1][s]):a
                        @inbounds push!($cache[n][S][m1][s],$T[])
                    end
                    @inbounds for k ∈ length($cache[n][S][m1][s][a1]):b
                        @inbounds push!($cache[n][S][m1][s][a1],$calc(V,a,k))
                    end
                    @inbounds $cache[n][S][m1][s][a1][b+1]
                end
            end
        end
    end
    @eval @pure $par(a::Basis{V,G,B},b::Basis{V,L,C}) where {V,G,B,L,C} = $par(bits(a),bits(b),V)
end

import Base: signbit, imag, real
export odd, even, angular, radial, ₊, ₋, ǂ

@pure signbit(V::T) where T<:Manifold{N} where N = (ib=indexbasis(N); parity.(ib,ib,Ref(V)))
@pure signbit(V::T,G) where T<:Manifold{N} where N = (ib=indexbasis(N,G); parity.(ib,ib,Ref(V)))
@pure angular(V::T) where T<:Manifold = SVector(findall(signbit(V))...)
@pure radial(V::T) where T<:Manifold = SVector(findall(.!signbit(V))...)
@pure angular(V::T,G) where T<:Manifold = findall(signbit(V,G))
@pure radial(V::T,G) where T<:Manifold = findall(.!signbit(V,G))

for (op,other) ∈ ((:angular,:radial),(:radial,:angular))
    @eval begin
        $op(t::T) where T<:TensorTerm{V,G} where {V,G} = basisindex(ndims(V),bits(basis(t))) ∈ $op(V,G) ? t : zero(V)
        function $op(t::Chain{V,G,T}) where {V,G,T}
            out = copy(value(t,mvec(ndims(V),G,T)))
            for k ∈ $other(V,G)
                @inbounds out[k]≠0 && (out[k] = zero(T))
            end
            Chain{V,G,T}(out)
        end
        function $op(t::MultiVector{V,T}) where {V,T}
            out = copy(value(t,mvec(ndims(V),T)))
            for k ∈ $other(V)
                @inbounds out[k]≠0 && (out[k] = zero(T))
            end
            MultiVector{V,T}(out)
        end
    end
end

odd(t::T) where T<:TensorGraded{V,G} where {V,G} = parityinvolute(G) ? t : zero(V)
even(t::T) where T<:TensorGraded{V,G} where {V,G} = parityinvolute(G) ? zero(V) : t
function odd(t::MultiVector{V,T}) where {V,T}
    N = ndims(V)
    out = copy(value(t,mvec(N,T)))
    bs = binomsum_set(N)
    @inbounds out[1]≠0 && (out[1] = zero(T))
    for g ∈ 3:2:N+1
        @inbounds for k ∈ bs[g]+1:bs[g+1]
            @inbounds out[k]≠0 && (out[k] = zero(T))
        end
    end
    MultiVector{V,T}(out)
end
function even(t::MultiVector{V,T}) where {V,T}
    N = ndims(V)
    out = copy(value(t,mvec(N,T)))
    bs = binomsum_set(N)
    for g ∈ 2:2:N+1
        @inbounds for k ∈ bs[g]+1:bs[g+1]
            @inbounds out[k]≠0 && (out[k] = zero(T))
        end
    end
    MultiVector{V,T}(out)
end

imag(t::T) where T<:TensorGraded{V,G} where {V,G} = parityreverse(G) ? t : zero(V)
real(t::T) where T<:TensorGraded{V,G} where {V,G} = parityreverse(G) ? zero(V) : t
function imag(t::MultiVector{V,T}) where {V,T}
    N = ndims(V)
    out = copy(value(t,mvec(N,T)))
    bs = binomsum_set(N)
    @inbounds out[1]≠0 && (out[1] = zero(T))
    for g ∈ 2:N+1
        @inbounds !parityreverse(g-1) && for k ∈ bs[g]+1:bs[g+1]
            @inbounds out[k]≠0 && (out[k] = zero(T))
        end
    end
    MultiVector{V,T}(out)
end
function real(t::MultiVector{V,T}) where {V,T}
    N = ndims(V)
    out = copy(value(t,mvec(N,T)))
    bs = binomsum_set(N)
    for g ∈ 3:N+1
        @inbounds parityreverse(g-1) && for k ∈ bs[g]+1:bs[g+1]
            @inbounds out[k]≠0 && (out[k] = zero(T))
        end
    end
    MultiVector{V,T}(out)
end
