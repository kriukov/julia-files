## Krawczyk method, based on Tucker p. 86

module KrawczykMethod
export krawczyk, differentiate, Interval, rad, diam, mid, mig, mag, belong, hd, hull, isect, isectext, K

using AutoDiff

println("Syntax: krawczyk(function, Interval(lo, hi), precision)")

K(f, x) = mid(x) - (Interval(1)//Interval(differentiate(f, mid(x))))*f(mid(x)) + (1 - (Interval(1)//Interval(differentiate(f, mid(x))))*differentiate(f, x))*(x - mid(x))



# Outside wrapping function was made in order for it to clean up the array of roots every time
function krawczyk(f::Function, a::Interval, bigprec::Integer)


  arr_a = Interval[]

  function krawczyk_internal(f::Function, a::Interval, bigprec::Integer=64)

    set_bigfloat_precision(bigprec)
    tol = 1e-15 #100eps(BigFloat)



    # If a is symmetric, i.e., mid(a) = 0, the process may stall. The initial interval should be slightly asymmetrized then
    if mid(a) == 0
      a = Interval(a.lo, a.hi + 0.0001*mag(a))
    end

    Ka = isect(a, K(f, a))
    #@show Ka

    if Ka != false
      #@show diam(a)
      #@show diam(K(a))


      if diam(Ka) < tol
        if a.lo < Ka.lo && Ka.hi < a.hi   # inside
          println("Unique zero in $(Ka)")
          push!(arr_a, Ka)
        else
          println("Maybe a zero in $(Ka)")
        end

      else
        krawczyk_internal(f, Interval(Ka.lo, mid(Ka)), bigprec)
        krawczyk_internal(f, Interval(mid(Ka), Ka.hi), bigprec)
      end

    end

    return arr_a
  end


  return krawczyk_internal(f, a, bigprec)
end

#end of module
end