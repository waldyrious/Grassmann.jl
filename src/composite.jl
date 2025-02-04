
#   This file is part of Grassmann.jl. It is licensed under the GPL license
#   Grassmann Copyright (C) 2019 Michael Reed

export exph, log_fast, logh_fast

## exponential & logarithm function

@inline Base.expm1(t::Basis{V,0}) where V = Simplex{V}(ℯ-1)
@inline Base.expm1(t::T) where T<:TensorGraded{V,0} where V = Simplex{V}(DirectSum.expm1(value(T<:TensorTerm ? t : scalar(t))))

function Base.expm1(t::T) where T<:TensorAlgebra{V} where V
    S,term,f = t,(t^2)/2,norm(t)
    norms = SizedVector{3}(f,norm(term),f)
    k::Int = 3
    @inbounds while norms[2]<norms[1] || norms[2]>1
        S += term
        ns = norm(S)
        @inbounds ns ≈ norms[3] && break
        term *= t/k
        @inbounds norms .= (norms[2],norm(term),ns)
        k += 1
    end
    return S
end

@eval @generated function Base.expm1(b::MultiVector{V,T}) where {V,T}
    loop = generate_loop_multivector(V,:term,:B,:*,:geomaddmulti!,geomaddmulti!_pre,:k)
    return quote
        B = value(b)
        sb,nb = scalar(b),norm(B)
        sb ≈ nb && (return Simplex{V}(DirectSum.expm1(value(sb))))
        $(insert_expr(loop[1],:mvec,:T,Float64)...)
        S = zeros(mvec(N,t))
        term = zeros(mvec(N,t))
        S .= B
        out .= value(b^2)/2
        norms = SizedVector{3}(nb,norm(out),norm(term))
        k::Int = 3
        @inbounds while (norms[2]<norms[1] || norms[2]>1) && k ≤ 10000
            S += out
            ns = norm(S)
            @inbounds ns ≈ norms[3] && break
            term .= out
            out .= 0
            # term *= b/k
            $(loop[2])
            @inbounds norms .= (norms[2],norm(out),ns)
            k += 1
        end
        return MultiVector{V,t}(S)
    end
end

@inline unabs!(t) = t
@inline unabs!(t::Expr) = (t.head == :call && t.args[1] == :abs) ? t.args[2] : t

function Base.exp(t::T) where T<:TensorGraded{V,G} where {V,G}
    S = T<:Basis
    i = T<:TensorTerm ? basis(t) : t
    sq = i*i
    if isscalar(sq)
        hint = value(scalar(sq))
        isnull(hint) && (return 1+t)
        G==0 && (return Simplex{V}(DirectSum.exp(value(S ? t : scalar(t)))))
        θ = unabs!(DirectSum.sqrt(DirectSum.abs(value(scalar(abs2(t))))))
        hint<0 ? DirectSum.cos(θ)+t*(S ? DirectSum.sin(θ) : DirectSum.:/(DirectSum.sin(θ),θ)) : DirectSum.cosh(θ)+t*(S ? DirectSum.sinh(θ) : DirectSum.:/(DirectSum.sinh(θ),θ))
    else
        return 1+expm1(t)
    end
end

function Base.exp(t::T,::Val{hint}) where T<:TensorGraded{V,G} where {V,G,hint}
    S = T<:Basis
    i = T<:TensorTerm ? basis(t) : t
    sq = i*i
    if isscalar(sq)
        isnull(hint) && (return 1+t)
        G==0 && (return Simplex{V}(DirectSum.exp(value(S ? t : scalar(t)))))
        θ = unabs!(DirectSum.sqrt(DirectSum.abs(value(scalar(abs2(t))))))
        hint<0 ? DirectSum.cos(θ)+t*(S ? DirectSum.sin(θ) : DirectSum.:/(DirectSum.sin(θ),θ)) : DirectSum.cosh(θ)+t*(S ? DirectSum.sinh(θ) : DirectSum.:/(DirectSum.sinh(θ),θ))
    else
        return 1+expm1(t)
    end
end

function Base.exp(t::MultiVector)
    st = scalar(t)
    mt = t-scalar(t)
    sq = mt*mt
    if isscalar(sq)
        hint = value(scalar(sq))
        isnull(hint) && (return DirectSum.exp(value(st))*(1+t))
        θ = unabs!(DirectSum.sqrt(DirectSum.abs(value(scalar(abs2(mt))))))
        return DirectSum.exp(value(st))*(hint<0 ? DirectSum.cos(θ)+mt*(DirectSum.:/(DirectSum.sin(θ),θ)) : DirectSum.cosh(θ)+mt*(DirectSum.:/(DirectSum.sinh(θ),θ)))
    else
        return 1+expm1(t)
    end
end

function Base.exp(t::MultiVector,::Val{hint}) where hint
    st = scalar(t)
    mt = t-scalar(t)
    sq = mt*mt
    if isscalar(sq)
        isnull(hint) && (return DirectSum.exp(value(st))*(1+t))
        θ = unabs!(DirectSum.sqrt(DirectSum.abs(value(scalar(abs2(mt))))))
        return DirectSum.exp(value(st))*(hint<0 ? DirectSum.cos(θ)+mt*(DirectSum.:/(DirectSum.sin(θ),θ)) : DirectSum.cosh(θ)+mt*(DirectSum.:/(DirectSum.sinh(θ),θ)))
    else
        return 1+expm1(t)
    end
end

function qlog(w::T,x::Int=10000) where T<:TensorAlgebra{V} where V
    w2,f = w^2,norm(w)
    prod = w*w2
    S,term = w,prod/3
    norms = SizedVector{3}(f,norm(term),f)
    k::Int = 5
    @inbounds while (norms[2]<norms[1] || norms[2]>1) && k ≤ x
        S += term
        ns = norm(S)
        @inbounds ns ≈ norms[3] && break
        prod *= w2
        term = prod/k
        @inbounds norms .= (norms[2],norm(term),ns)
        k += 2
    end
    return 2S
end # http://www.netlib.org/cephes/qlibdoc.html#qlog

@eval @generated function qlog_fast(b::MultiVector{V,T,E},x::Int=10000) where {V,T,E}
    loop = generate_loop_multivector(V,:prod,:B,:*,:geomaddmulti!,geomaddmulti!_pre)
    return quote
        $(insert_expr(loop[1],:mvec,:T,Float64)...)
        f = norm(b)
        w2::MultiVector{V,T,E} = b^2
        B = value(w2)
        S = zeros(mvec(N,t))
        prod = zeros(mvec(N,t))
        term = zeros(mvec(N,t))
        S .= value(b)
        out .= value(b*w2)
        term .= out/3
        norms = SizedVector{3}(f,norm(term),f)
        k::Int = 5
        @inbounds while (norms[2]<norms[1] || norms[2]>1) && k ≤ x
            S += term
            ns = norm(S)
            @inbounds ns ≈ norms[3] && break
            prod .= out
            out .= 0
            # prod *= w2
            $(loop[2])
            term .= out/k
            @inbounds norms .= (norms[2],norm(term),ns)
            k += 2
        end
        S *= 2
        return MultiVector{V,t}(S)
    end
end

@inline Base.log(t::T) where T<:TensorAlgebra = qlog((t-1)/(t+1))
@inline Base.log1p(t::T) where T<:TensorAlgebra = qlog(t/(t+2))

for (qrt,n) ∈ ((:sqrt,2),(:cbrt,3))
    @eval begin
        @inline Base.$qrt(t::Basis{V,0} where V) = t
        @inline Base.$qrt(t::T) where T<:TensorGraded{V,0} where V = Simplex{V}($Sym.$qrt(value(T<:TensorTerm ? t : scalar(t))))
        @inline function Base.$qrt(t::T) where T<:TensorAlgebra
            isscalar(t) ? $qrt(scalar(t)) : exp(log(t)/$n)
        end
    end
end

## trigonometric

@inline Base.cosh(t::T) where T<:TensorGraded{V,0} where V = Simplex{V}(DirectSum.cosh(value(T<:TensorTerm ? t : scalar(t))))

function Base.cosh(t::T) where T<:TensorAlgebra{V} where V
    τ = t^2
    S,term = τ/2,(τ^2)/24
    f = norm(S)
    norms = SizedVector{3}(f,norm(term),f)
    k::Int = 6
    @inbounds while norms[2]<norms[1] || norms[2]>1
        S += term
        ns = norm(S)
        @inbounds ns ≈ norms[3] && break
        term *= τ/(k*(k-1))
        @inbounds norms .= (norms[2],norm(term),ns)
        k += 2
    end
    return 1+S
end

@eval @generated function Base.cosh(b::MultiVector{V,T,E}) where {V,T,E}
    loop = generate_loop_multivector(V,:term,:B,:*,:geomaddmulti!,geomaddmulti!_pre,:(k*(k-1)))
    return quote
        sb,nb = scalar(b),norm(b)
        sb ≈ nb && (return Simplex{V}(DirectSum.cosh(value(sb))))
        $(insert_expr(loop[1],:mvec,:T,Float64)...)
        τ::MultiVector{V,T,E} = b^2
        B = value(τ)
        S = zeros(mvec(N,t))
        term = zeros(mvec(N,t))
        S .= value(τ)/2
        out .= value((τ^2))/24
        norms = SizedVector{3}(norm(S),norm(out),norm(term))
        k::Int = 6
        @inbounds while (norms[2]<norms[1] || norms[2]>1) && k ≤ 10000
            S += out
            ns = norm(S)
            @inbounds ns ≈ norms[3] && break
            term .= out
            out .= 0
            # term *= τ/(k*(k-1))
            $(loop[2])
            @inbounds norms .= (norms[2],norm(out),ns)
            k += 2
        end
        @inbounds S[1] += 1
        return MultiVector{V,t}(S)
    end
end

@inline Base.sinh(t::T) where T<:TensorGraded{V,0} where V = Simplex{V}(DirectSum.sinh(value(T<:TensorTerm ? t : scalar(t))))

function Base.sinh(t::T) where T<:TensorAlgebra{V} where V
    τ,f = t^2,norm(t)
    S,term = t,(t*τ)/6
    norms = SizedVector{3}(f,norm(term),f)
    k::Int = 5
    @inbounds while norms[2]<norms[1] || norms[2]>1
        S += term
        ns = norm(S)
        @inbounds ns ≈ norms[3] && break
        term *= τ/(k*(k-1))
        @inbounds norms .= (norms[2],norm(term),ns)
        k += 2
    end
    return S
end

@eval @generated function Base.sinh(b::MultiVector{V,T,E}) where {V,T,E}
    loop = generate_loop_multivector(V,:term,:B,:*,:geomaddmulti!,geomaddmulti!_pre,:(k*(k-1)))
    return quote
        sb,nb = scalar(b),norm(b)
        sb ≈ nb && (return Simplex{V}(DirectSum.sinh(value(sb))))
        $(insert_expr(loop[1],:mvec,:T,Float64)...)
        τ::MultiVector{V,T,E} = b^2
        B = value(τ)
        S = zeros(mvec(N,t))
        term = zeros(mvec(N,t))
        S .= value(b)
        out .= value(b*τ)/6
        norms = SizedVector{3}(norm(S),norm(out),norm(term))
        k::Int = 5
        @inbounds while (norms[2]<norms[1] || norms[2]>1) && k ≤ 10000
            S += out
            ns = norm(S)
            @inbounds ns ≈ norms[3] && break
            term .= out
            out .= 0
            # term *= τ/(k*(k-1))
            $(loop[2])
            @inbounds norms .= (norms[2],norm(out),ns)
            k += 2
        end
        return MultiVector{V,t}(S)
    end
end

exph(t) = Base.cosh(t)+Base.sinh(t)

for (logfast,expf) ∈ ((:log_fast,:exp),(:logh_fast,:exph))
    @eval function $logfast(t::T) where T<:TensorAlgebra{V} where V
        term = zero(V)
        norm = SizedVector{2}(0.,0.)
        while true
            en = $expf(term)
            term -= 2(en-t)/(en+t)
            @inbounds norm .= (norm[2],norm(term))
            @inbounds norm[1] ≈ norm[2] && break
        end
        return term
    end
end

#=function log(t::T) where T<:TensorAlgebra{V} where V
    norms::Tuple = (norm(t),0)
    k::Int = 3
    τ = t-1
    if true #norms[1] ≤ 5/4
        prods = τ^2
        terms = TensorAlgebra{V}[τ,prods/2]
        norms = (norms[1],norm(terms[2]))
        while (norms[2]<norms[1] || norms[2]>1) && k ≤ 3000
            prods = prods*t
            push!(terms,prods/(k*(-1)^(k+1)))
            norms = (norms[2],norm(terms[end]))
            k += 1
        end
    else
        s = inv(t*inv(τ))
        prods = s^2
        terms = TensorAlgebra{V}[s,2prods]
        norms = (norm(terms[1]),norm(terms[2]))
        while (norms[2]<norms[1] || norms[2]>1) && k ≤ 3000
            prods = prods*s
            push!(terms,k*prods)
            norms = (norms[2],norm(terms[end]))
            k += 1
        end
    end
    return sum(terms[1:end-1])
end=#
