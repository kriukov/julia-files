using ValidatedNumerics
#using AutoDiff
using ForwardDiff
using PurityIntervalsVN
using KrawczykMethod2DVN

#using FastAnonymous

typealias prec Float64

import Base.convert; convert(Interval, x::Float64) = Interval(x, x)

########################################### Necessary function from IA not defined in VN
#import Base.in
in(x, y::Interval) = ValidatedNumerics.in(x,y)

import Base.isnan
function isnan(x::IntervalBox)
    if isnan(x[1].lo) || isnan(x[1].hi) || isnan(x[2].lo) || isnan(x[2].hi)
        return true
    else
        return false
    end
end


import Base.unique
function unique(x)
    x1 = Interval[]
    for i = 1:length(x)
        k = 0
        for j = i+1:length(x)
            k += (x[j] == x[i])            
        end
        if k == 0
            #@show x[i]
            push!(x1, x[i])
        end
    end
    #@show length(x1)
    x1
end

# Replace intersecting intervals in an array with their hull
function collapse_isect_step(x)
    x1 = unique(x)
    l = length(x1)
    for i = 1:l
        for j = i+1:l
            if intersect(x1[i], x1[j]) != ∅
                hull_ij = hull(x1[i], x1[j])
                deleteat!(x1, (i, j))
                push!(x1, hull_ij, Interval(Inf, Inf))
            end
        end
    end
    x2 = unique(x1)
    sort!(x2)
    # After uniqueness and sorting, there will be only one Interval(Inf, Inf) at the very end. Remove it
    if length(x2) > 0 && x2[length(x2)] == Interval(Inf, Inf)
        pop!(x2)
    end
    x2
end

# Repeat the collapse steps until the array does not change
function collapse_isect(x)
    # If the array consists of a single interval (NaN, NaN), it may cause an infinite loop. Make an exception
    if length(x) == 1
        if isnan(x[1])
        return [∅]
        end
    end
    x1 = x
    x2 = Interval[]
    i = 0
    while true # i < 10
        #@show diam(x1)
        x2 = collapse_isect_step(x1)
        x1 == x2 && break
        x1 = x2
        #@show i += 1
    end
    #println("Result of collapse_isect after $i iterations: $x2")
    x2
end

###### IntUnions

type IntUnion
	unionbody::Array{Interval, 1}
	function IntUnion(x)
	    #println("Initial argument of IntUnion: $x")
	    x1 = collapse_isect(x)
        #println("Collapsed argument of IntUnion: $x1")
	    new(x1)
	end
end


# Four arithmetic operations on IntUnions
import Base.+, Base.-, Base.*, Base./
for func in (:+, :-, :*, :/)
    @eval begin
        function $func(x::IntUnion, y::IntUnion)
            res = Interval[]
            for i = 1:length(x.unionbody)
                for j = 1:length(y.unionbody)
                    push!(res, $func(x.unionbody[i], y.unionbody[j]))
                end
            end
            return IntUnion(res)
        end
    end
end

import Base.exp, Base.log, Base.sin, Base.cos, Base.tan, Base.asin, Base.acos, Base.atan, Base.abs, Base.sqrt
for func in (:exp, :log, :sin, :cos, :tan, :asin, :acos, :atan, :abs, :sqrt)
    @eval begin
        function $func(x::IntUnion)
            IntUnion(map($func, x.unionbody))
        end
    end
end

+(x::IntUnion, y) = x + IntUnion([y])
+(x, y::IntUnion) = y + x
-(x::IntUnion) = IntUnion(-x.unionbody)
-(x::IntUnion, y) = x - IntUnion([y])
-(x, y::IntUnion) = - (y - x)
*(x::IntUnion, y) = x*IntUnion([y])
*(x, y::IntUnion) = y*x
/(x::IntUnion, y) = x/IntUnion([y])
/(x, y::IntUnion) = 1/(y/x)

# -(x::Array{Any,1}, y::ValidatedNumerics.IntervalBox) = 

import Base.intersect
function intersect(x::IntUnion, y::IntUnion)
    res = Interval[]
    for i = 1:length(x.unionbody)
        for j = 1:length(y.unionbody)
            isect_ij = intersect(x.unionbody[i], y.unionbody[j])
            if isect_ij != ∅
                push!(res, isect_ij)
            end
        end
    end
    if length(res) == 0
        return ∅
    else
        return IntUnion(res)
    end
end

intersect(x::IntUnion, y::Interval) = intersect(x, IntUnion([y]))
intersect(x::Interval, y::IntUnion) = intersect(y, x)
#=
intersect(x::MultiDimInterval, y::Array{Any, 1}) = [intersect(x[1], y[1]), intersect(x[2], y[2])]
intersect(x::Array{Any, 1}, y::IntervalBox) = intersect(y, x)
intersect(x::IntervalBox, y::Array{IntUnion, 1}) = [intersect(x[1], y[1]), intersect(x[2], y[2])]
=#
function in(x::IntUnion, y::Interval)
    k = 0
    for i = 1:length(x.unionbody)
        k += !in(x.unionbody[i], y)
    end
    if k > 0
        return false
    else 
        return true
    end
end

import Base.mod2pi
function mod2pi(x::Interval)
    if x == ∅
        return ∅
    end
	if diam(x) >= 2pi
		return Interval(0, 2pi)
	else
		if in((floor(x.lo/(2pi)) + 1)*2pi, x)
			return IntUnion([Interval(0, mod2pi(x.hi)), Interval(mod2pi(x.lo), 2pi)]) 
		else
			return Interval(mod2pi(x.lo), mod2pi(x.hi))
		end
	end
end

function mod2pi(x::IntUnion)
    #println("mod of IntUnion! arg: ", x)
    res = Interval[]
    for i = 1:length(x.unionbody)
        res_element = mod2pi(x.unionbody[i])
        if typeof(res_element) == Interval{prec}
            push!(res, res_element)
        elseif typeof(res_element) == IntUnion
            push!(res, res_element.unionbody[1])
            push!(res, res_element.unionbody[2])
        end            
    end
    IntUnion(res)
end

Base.mod2pi(d::ForwardDiff.Dual) = ForwardDiff.Dual{2, Interval}(mod2pi(ForwardDiff.value(d)), ForwardDiff.partials(d))
Base.mod2pi(d::ForwardDiff.Dual) = ForwardDiff.Dual{2, IntUnion}(mod2pi(ForwardDiff.value(d)), ForwardDiff.partials(d))
Base.mod2pi(d::ForwardDiff.Dual) = ForwardDiff.Dual{2, Float64}(mod2pi(ForwardDiff.value(d)), ForwardDiff.partials(d))

####### IntUnion2D

type IntUnion2D
	unionbody::Array{IntervalBox, 1}
end

# Four arithmetic operations on IntUnion2D
import Base.+, Base.-, Base.*, Base./
for func in (:+, :-, :*, :/)
    @eval begin
        function $func(x::IntUnion2D, y::IntUnion2D)
            res = IntervalBox[]
            for i = 1:length(x.unionbody)
                for j = 1:length(y.unionbody)
                    push!(res, $func(x.unionbody[i], y.unionbody[j]))
                end
            end
            return IntUnion2D(res)
        end
    end
end

+(x::IntUnion2D, y::IntervalBox) = x + IntUnion2D([y])
+(x::IntervalBox, y::IntUnion2D) = y + x
-(x::IntUnion2D) = IntUnion2D(-x.unionbody)
-(x::IntUnion2D, y) = x - IntUnion2D([y])
-(x::IntervalBox, y::IntUnion2D) = - (y - x)
*(x::IntUnion2D, y::IntervalBox) = x*IntUnion2D([y])
*(x::IntervalBox, y::IntUnion2D) = y*x
/(x::IntUnion2D, y::IntervalBox) = x/IntUnion2D([y])
/(x::IntervalBox, y::IntUnion2D) = 1/(y/x)

###########################################

# The vector x = [ω, θ] in Birkhoff mapping

function alpha(n, m)
	if n > 0 && n <= 3 && m > 0 && m <= 3 && typeof(n) == Int && typeof(m) == Int && n != m
		k = pi/3
		if n == 1 && m == 2
			return 0
		elseif n == 1 && m == 3
	 		return k
		elseif n == 2 && m == 3
	 		return 2k
		elseif n == 2 && m == 1
	 		return 3k
		elseif n == 3 && m == 1
	 		return 4k
		elseif n == 3 && m == 2
	 		return 5k
	 	end
	else
	    error("Invalid parameters: should be 1, 2, 3 and not equal")
	end
end

function T(x, n, m, r)
	ω, θ = x
    #@show x, n, m 
	ω_next = ω - r*(ω*cos(θ - alpha(n, m)) + √(1 - ω^2)*sin(θ - alpha(n, m)))
	θ_next = mod2pi(θ + big(pi) + asin(ω) + asin(ω_next))
	#θ_next = θ + big(pi) + asin(ω) + asin(ω_next)
	
    [ω_next, θ_next]
end

function T1(x, n, m, r)
	ω, θ = x
    #@show x, n, m 
	ω_next = ω - r*(ω*cos(θ - alpha(n, m)) + √(1 - ω^2)*sin(θ - alpha(n, m)))
	θ_next = θ + big(pi) + asin(ω) + asin(ω_next)
	#θ_next = θ + big(pi) + asin(ω) + asin(ω_next)
	
    [ω_next, θ_next]
end

function T(x::Array{IntervalBox, 1}, n, m, r)
	sol = IntervalBox[]
	for i = 1:length(x)
		push!(sol, T(x[i], n, m, r))
	end
	return sol
end


using PyPlot

distance_between_centers = 6.

# x = [ω, θ] and n is array of path points, e.g. [1, 2, 3, 1, 3]
function path(x, n)
    for i = 1:length(n)-1
        if n[i] != n[i+1]
            x = T(x, n[i], n[i+1], distance_between_centers)
        else
            error("Cannot hit the same disk twice in succession")
        end
    end
    x
end

# Non-bisection inefficient plotting
function plot_band(f, N)

	# Split the phase space w = [-1, 1], th = [0, pi/3] into 30x30 rectangles
	rw = Interval(-0.95, 0.95)
	rth = Interval(0.05, float(pi)/3-0.05)
	deltaw = diam(rw/N)
	deltath = diam(rth/N)

	points = Array{BigFloat, 1}[]
	purities = Int[]

	for i = 1:N
		for j = 1:N
			rect = [rw.lo + i*deltaw - Interval(0, deltaw), rth.lo + j*deltath - Interval(0, deltath)]
			p = purity(f, rect)
			#println([rect, p])
			push!(points, mid(rect))
			push!(purities, p)

		end
	end

	x = [Float64(xx[1]) for xx in points]
	y = [Float64(xx[2]) for xx in points]

	p = purities

	for i in (0, 1, -1)
		plot(y[p.==i], x[p.==i], "o", label="$i", alpha = 0.5)
	end
	legend()

end

#plot_band(f12)
#plot_band(f13)

#plot_band(twice_123, 100)
#plot_band(x -> path(x, [1, 2, 3]), 100)

rect = IntervalBox(-0.999..0.999, 0.001..(big(pi)/3-0.001))
#points = Array{Interval, 1}[]
points = IntervalBox[]
purities = Int[]

# More efficient plotting without dirty rectangles
function plot_band_bisection(f, rect, tol)
    limitrect(rect) = max(diam(rect[1]), diam(rect[2])) < tol
    p = purity(f, rect)
    if p != -1
        if p == 1
            #println("Went to p=1")
            push!(points, rect)
            push!(purities, p)
            #println("Clean recorded")
        elseif p == 0
            #println("Went to p=0")
            if limitrect(rect)
                push!(points, rect)
                push!(purities, p)
                #println("Unclean recorded")
            else
                pieces = bisect(rect)
                for i = 1:4
                    plot_band_bisection(f, pieces[i], tol)
                end
            end
        end
    end
    points, purities
end

# Plotting that includes dirty rectangles
function plot_band_bisection_dirty(f, rect, tol)
    limitrect(rect) = max(diam(rect[1]), diam(rect[2])) < tol
    p = purity(f, rect)
    if p == 1 || p == -1
        push!(points, rect)
        push!(purities, p)
    elseif p == 0
        if limitrect(rect)
            push!(points, rect)
            push!(purities, p)
        else
            pieces = bisect(rect)
            for i = 1:4
                plot_band_bisection_dirty(f, pieces[i], tol)
            end
        end
    end
    points, purities
end

# Using midpoints of rectangles! It works
#=
pts = mid(plot_band_bisection(x -> path(x, [1, 2]), rect, 1e-3))
x = [Float64(xx[1]) for xx in pts]
y = [Float64(xx[2]) for xx in pts]
plot(y, x, "o")
=#

# Function to draw rectangles
using PyCall
@pyimport matplotlib.patches as patches
rectangle = patches.Rectangle
function draw_rectangle(x, y, xwidth, ywidth, color="grey")
    ax = gca()
    ax[:add_patch](rectangle((x, y), xwidth, ywidth, facecolor=color, alpha=0.5, linewidth=0))
end


#=
plot_band_bisection(x -> path(x, [1, 2]), rect, 1e-3)
println(points)
println(purities)
=#

#result = plot_band_bisection(x -> path(x, [1, 2]), rect, 1e-2)

# Printing output for WM
#=
for i = 1:length(result[1])
    println("$(result[1][i][1].lo) $(result[1][i][1].hi) $(result[1][i][2].lo) $(result[1][i][2].hi) $(result[2][i])")
end
=#



#= Draw domain of T[...] without dirty

points, purities = plot_band_bisection(x -> path(x, [1, 2]), rect, 1e-2)
for i = 1:length(points)
    if purities[i] == 0
        draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "green")
    elseif purities[i] == 1
        draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "blue")
    end
end
axis([0, pi/3, -1, 1])
savefig("T12-domain.pdf")
=#

# Draw domain of T12 with dirty
#=
points, purities = plot_band_bisection_dirty(x -> path(x, [1, 2]), rect, 1e-3)
for i = 1:length(points)
    if purities[i] == 0
        draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "green")
    elseif purities[i] == 1
        draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "blue")
    elseif purities[i] == -1
        draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "red")
    end
end
axis([0, pi/3, -1, 1])
=#


#f(x) = path(x, [1, 2, 3, 1]) - x
#a = [Interval(-0.5-0.001, -0.5+0.001), Interval(pi/6-0.001, pi/6+0.001)]

#f(x) = path(x, [1, 2, 3, 1, 3, 1]) - x

#krawczyk2d_purity(f, rect, 64, 1e-4)
#krawczyk2d_purity(f, a, 64, 1e-4)

#rect = [Interval(-0.95, 0.95), Interval(0.05, big(pi)/3-0.05)]
#rect = [Interval(-0.51, -0.02), Interval(0.05, big(pi)/6-0.05)]
#krawczyk2d_purity(f, rect, 64, 1e-4)

# Draw the image/range
#points, purities = plot_band_bisection(x -> path(x, [1, 2, 3, 1]), rect, 5e-5)
#=
points0 = readdlm("points.dat")
points = IntervalBox[]
for i = 1:length(points0)
    push!(points, eval(parse(points0[i])))
end

purities = readdlm("purities.dat")

for i = 1:length(points)
    if purities[i] == 1
        @show point_image = path(points[i], [1, 2, 3, 1])
        if typeof(point_image[1]) == Interval && typeof(point_image[2]) == Interval
            draw_rectangle(point_image[2].lo, point_image[1].lo, diam(point_image[2]), diam(point_image[1]), "blue")
        elseif typeof(point_image[1]) == Interval && typeof(point_image[2]) == IntUnion
            for i = 1:length(point_image[2].union)
                draw_rectangle(point_image[2].union[i].lo, point_image[1].lo, diam(point_image[2].union[i]), diam(point_image[1]), "blue")
            end
        elseif typeof(point_image[1]) == IntUnion && typeof(point_image[2]) == Interval
            for i = 1:length(point_image[1].union)
                draw_rectangle(point_image[2].lo, point_image[1].union[i].lo, diam(point_image[2]), diam(point_image[1].union[i]), "blue")
            end
        elseif typeof(point_image[1]) == IntUnion && typeof(point_image[2]) == IntUnion
            for i = 1:length(point_image[1].union)
                for j = 1:length(point_image[2].union)
                    draw_rectangle(point_image[2].union[j].lo, point_image[1].union[i].lo, diam(point_image[2].union[j]), diam(point_image[1].union[i]), "blue")
                end
            end
        end
    end
end
axis([0, 2pi, -1, 1])
=#

#savefig("T1231-range.pdf")
#=
f(x) = path(x, [1, 2, 3]) - x
points, purities = plot_band_bisection(f, rect, 2e-3)
points1, purities1 = plot_band_bisection(x->path(x,[1,2])-x, rect, 1e-3)
for i = 1:length(points)
    if purities[i] == 0
        draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "green")
    elseif purities[i] == 1
        draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "blue")
    end
end
for i = 1:length(points1)
    if purities1[i] == 0
        draw_rectangle(points1[i][2].lo, points1[i][1].lo, diam(points1[i][2]), diam(points1[i][1]), "black")
    elseif purities1[i] == 1
        draw_rectangle(points1[i][2].lo, points1[i][1].lo, diam(points1[i][2]), diam(points1[i][1]), "red")
    end
end
axis([0, pi/3, -1, 1])
=#


c = Array{prec, 1}[]
r0 = 6
#push!(c, [Interval(0), Interval(0)], [Interval(r0), Interval(0)], [Interval(r0/2), Interval(r0*sqrt(3)/2)])
push!(c, [0, 0], [r0, 0], [r0/2, r0*sqrt(3)/2])

function table(c)
    N = length(c)
    r = zeros(prec, N, N)
    a = zeros(prec, N, N)
    for i = 1:N
        for j = 1:N
            r[i, j] = sqrt((c[i][1] - c[j][1])^2 + (c[i][2] - c[j][2])^2)
            a[i, j] = atan2((c[j] - c[i])[2], (c[j] - c[i])[1])
        end
    end
    r, a
end

#typealias IntUnion2D Array{Union{IntUnion, Interval}, 1}
#import Base.convert; convert(IntUnion, x::Interval) = IntUnion([x])


function T0(x, c, n, m)
	ω, θ = x
	println("Argument into T0 with $n, $m: $x")
	r_nm, a_nm = table(c)
	
	ω_next = ω - r_nm[n, m]*(ω*cos(θ - a_nm[n, m]) + √(1 - ω^2)*sin(θ - a_nm[n, m]))
	θ_next = mod2pi(θ + prec(pi) + asin(ω) + asin(ω_next))

    @show ω_next, θ_next
	#=
	if typeof(θ_next) == Interval{Float64}
		return IntervalBox(ω_next, θ_next)
	elseif typeof(θ_next) == IntUnion
		res = IntervalBox[]
		for i = 1:length(θ_next.unionbody)
			push!(res, IntervalBox(ω_next, θ_next.unionbody[i]))
		end
	return IntUnion2D([res])
	end
	=#
	return IntervalBox(ω_next, θ_next)
end

function T0gen(x, c, n, m)
	if typeof(x) == IntervalBox{2, Float64}
		return T0(x, c, n, m)
	else
		res = IntervalBox[]
		th_parts = x[2].unionbody
		for i = 1:length(th_parts)
			push!(res, T0(IntervalBox(x[1], th_parts[i]), c, n, m))
		end
		return IntUnion2D([res])
	end
end

function path_general(x, c, n)
    for i = 1:length(n)-1
        if n[i] != n[i+1]
            @show x = T0(x, c, n[i], n[i+1])
        else
            error("Cannot hit the same disk twice in succession")
        end
    end
    x
end

function draw_phase_space(c, n, rect, tol)
    points, purities = plot_band_bisection(x -> path_general(x, c, n), rect, tol)
    for i = 1:length(points)
        if purities[i] == 0
            draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "green")
        elseif purities[i] == 1
            draw_rectangle(points[i][2].lo, points[i][1].lo, diam(points[i][2]), diam(points[i][1]), "blue")
        end
    end
    axis([0, pi/3, -1, 1])
end

function collect_phase_space(c, n, rect, tol)
    points1 = IntervalBox[]
    points, purities = plot_band_bisection(x -> path_general(x, c, n), rect, tol)
    for i = 1:length(points)
        if purities[i] == 1
            push!(points1, points[i])
        end
    end
    return points1
end

function find_periodic_orbits(c, n, rect, tol)
   f(x) = path_general(x, c, n)
   #f = @anon x -> path_general(x, c, n) - x
   krawczyk2d_purity_periodic(f, rect, tol)
   #krawczyk2d_purity(f, rect, prec, tol)
end

function find_periodic_orbits_newton(c, n, rect, prec, tol)
   f(x) = path_general(x, c, n) - x
   #f = @anon x -> path_general(x, c, n) - x
   newton2d_purity(f, rect, prec, tol)
   #krawczyk2d_purity(f, rect, prec, tol)
end


# Time/distance function
function distance(x, c, n, m)
	ω, θ = x
	
	r_nm, a_nm = table(c)
	
	ω_next = ω - r_nm[n, m]*(ω*cos(θ - a_nm[n, m]) + √(1 - ω^2)*sin(θ - a_nm[n, m]))
	θ_next = mod(θ + prec(pi) + asin(ω) + asin(ω_next), 2π)
	
	t_next = sqrt(r_nm[n, m]^2 + 2r_nm[n, m]*(cos(θ_next - a_nm[n, m]) - cos(θ - a_nm[n, m])) + 2 - 2*cos(θ_next - θ))
    t_next
end

# Draw phase space from n-th disk to all other - here "n" is a number

function draw_phase_space_general(c, n, rect, tol)
    points = Array{IntervalBox, 1}[]
    purities = Array{Int, 1}[]
    for i = 1:length(c)
        if i != n
            points_i, purities_i = plot_band_bisection(x -> path_general(x, c, [n, i]) - x, rect, tol)
            push!(points, points_i)
            push!(purities, purities_i)
        end
    end
    
    for i = 1:length(points)
        for j = 1:length(points[i])
            if purities[i][j] == 0
                draw_rectangle(points[i][j][2].lo, points[i][j][1].lo, diam(points[i][j][2]), diam(points[i][j][1]), "green")
            elseif purities[i][j] == 1
                draw_rectangle(points[i][j][2].lo, points[i][j][1].lo, diam(points[i][j][2]), diam(points[i][j][1]), "blue")
            end
        end
    end

    axis([0, pi/3, -1, 1])
    
end

# Birkhoff 1-2 and 1-3 belts in a symmetric 3-disk scatterer
#draw_phase_space_general(c, 1, rect, 1e-2)

# Another system of disks: #2 is in the way of #3 from #1

c1 = Array{prec, 1}[]
push!(c1, [0, 0], [r0, 0], [r0/2, 1.3])

#draw_phase_space_general(c1, 1, rect, 1e-2)


#@time find_periodic_orbits(c, [1, 2], rect, 64, 1e-4)

#@time find_periodic_orbits(c, [1, 3, 1], [Interval(-0.012, 0.001), Interval(pi/3-0.01, pi/3+0.0011)], 64, 1e-4)

# Find periodic orbit 1-2-3-1 in isosceles system c1
#find_periodic_orbits(c1, [1, 2, 3, 1], rect, 64, 1e-4)

#find_periodic_orbits(c, [1, 2, 3, 1, 3, 1], rect, 64, 1e-4)
#f(x) = path_general(x, c, [1,2,3,1,3,1])
#a = [IntervalArithmetic.Interval(-0.74925,-0.4995),IntervalArithmetic.Interval(0.13164969389957473,0.26229938779914946)]
#purity(f,a)

##################





# Escape-time function

# Symmetric 3-disk scatterer with variable separation r0
function symmetric3(r0)
    c = Array{prec, 1}[]
    push!(c, [0, 0], [r0, 0], [r0/2, r0*sqrt(3)/2]) 
    c
end

# Symmetric 3-disk scatterer with variable separation r0 in Gaspard's orientation (with disk 1 rightmost on the x-axis)
function symmetric3g(r0)
    c = Array{prec, 1}[]
    push!(c, [r0/sqrt(3), 0], [-r0/(2*sqrt(3)), r0/2], [-r0/(2*sqrt(3)), -r0/2]) 
    c
end

cg = symmetric3g(3.5)

x0 = -10
#y0 = 0.15

# Not to confuse with Cartesian, denote Birkhoff 2D coordinate as b
# Time from (x0, y0) to the first collision is just the x-displacement

# Deprecated: use place1(); Given y0, output the Birkhoff point, disk and time of the first collision for symmetric3g  for v = [1, 0]
function place0(r0, x0, y0)
    if y0.hi < r0/2 - 1
        b0 = [y0, prec(pi) - asin(y0)]
        n0 = 1
        t0 = r0/sqrt(3) - x0 - sqrt(1 - y0^2)
        return b0, n0, t0
    elseif y0.lo > r0/2 - 1
        b0 = [r0/2 - y0, -acos(r0/2 - y0) - prec(pi)/2]
        n0 = 2
        t0 = -r0/(2*sqrt(3)) - x0 - sqrt(1 - y0^2)
        return b0, n0, t0
    end
    
end

# A general function for a first collision time from the outside point x with velocity v of the arbitrary system c
function place1(c, x, v)
    times = Interval[]
    x = map(Interval, x)
    v = map(Interval, v)
    n = length(c)
    crossz(x, y) = x[1]*y[2] - x[2]*y[1]
    norm2(x) = x[1]^2 + x[2]^2
    v2 = norm2(v)
	
    for i = 1:n
        X = x - c[i]
        Xcrossv = crossz(X, v)
        Xdotv = dot(X, v)
        discr = v2 - Xcrossv^2
        if discr.lo >= 0 #&& (-Xdotv - sqrt(discr)).lo >= 0 # If there is a real intersection ray-disk
            t = (-Xdotv - sqrt(discr))/v2
            push!(times, t)
        end
    end
    
	# Extract the minimum positive time value (in case there is more than one real intersection)
	t_minpos = Interval(Inf)
	k = 0
	for i = 1:length(times)
		if times[i].hi < t_minpos.lo && times[i].lo > 0
			t_minpos = times[i]
			k = i
		end				
	end
	
	# So it landed on disk k after time (not distance if v is not scaled). Convert into Birkhoff coordinates
	d = v*t_minpos # vector distance to first hit
	D = norm(d)
	R = x + d - c[k]
    th = atan2(R[2], R[1])
    if abs(d[1]) > abs(d[2])
        w = (d[2]*cos(th) - d[1]*sin(th))/D
    else
        phi = acos((d[1]*cos(th) + d[2]*sin(th))/D)
        w = sin(phi)
    end
    #@show (d[1]*cos(th) + d[2]*sin(th))/D
    #phi = th - atan2(d[2], d[1]) # Gives errors when the vector is (almost) horizontal
    
    b = [w, th]
    t = D/norm(v)
    
    return b, k, t
end


# Output escape time (time to last collision) for arbitrary disk system with fixed initial abscissa x and a range of ordinates y. Outputs midpoints of found intervals
function escape_time(c, x, y_range::Interval, v, tol)

	starting_intervals = split_range(y_range, tol)

	esctime_vs_y0 = Any[] #IntervalBox[] # May be IntUnions here (less likely with smaller tolerance), so change to something else or Any

	disks = range(1, length(c))

	for i = 1:length(starting_intervals)
		y = starting_intervals[i]
		b, n, t0 = place1(c, [Interval(x), y], v)
		
		counter = 1
		function collision_iterate_flat(n, rect_p, t0)
		    next_places = Array{PurityInterval, 1}[]
		    next_disks = Int[]
		    next_purities = Int[]
		    
		    for j = 1:length(c) # From disk n transition to all other
		        if j != n # ...except to n, of course
		            next_place = path_general(rect_p, c, [n, j])
		            push!(next_places, next_place)
		            push!(next_disks, j)
		            push!(next_purities, min(next_place[1].flag, next_place[2].flag))
		        end        
		    end
		    
		    #= In a system of non-screening disks (such as symmetric-3), in which a ray from one of the disks cannot 
		    intersect more than one disk, either all purities are -1 (particle escapes), or only one of all is equal 
		    to 0 or 1 (probably or certainly hits one of the disks). =#
		    
		    #@show next_purities
		    p_max = maximum(next_purities)
		    arr_ind = findfirst(next_purities, p_max)
		    k = next_disks[arr_ind]
		    next = next_places[arr_ind]
		    
		    if p_max == -1
		        #t0 += distance(rect_p, cg, n, j)
		        push!(esctime_vs_y0, [y, t0])
		        #println(counter, " collisions before escape starting from ", y)
		        #@show n, k
		    elseif p_max == 1
		        #@show rect_p
		        #@show n, k
		        if distance(rect_p, c, n, k).flag == 1
		            t0 += distance(unpurify(rect_p), c, n, k)
		            counter += 1
		            collision_iterate_flat(n, next, t0)
		        else
		            @show y
		            println("distance not clean! ", rect_p)
		        end
		    end
	end
		#@show b
		collision_iterate_flat(n, purify(b), t0)
	end

	z = Array{prec, 1}[]
	for i = 1:length(esctime_vs_y0)
		if typeof(esctime_vs_y0[i]) == IntervalBox
		    push!(z, mid(esctime_vs_y0[i]))
		end
	end

	return z
end


#z = escape_time(symmetric3g(3.5), -10, Interval(0.0001, 0.8), [1, 0], 1e-5)

#=
x = [Float64(xx[1]) for xx in z]
y = [Float64(log10(xx[2])) for xx in z]
plot(x, y, ".b-", markersize = 1, alpha = 0.5) # ".b-" means "dots connected with blue lines"
xlabel(L"{y_0}", fontsize=30); ylabel(L"\mathrm{lg} \, t_{esc}", fontsize=30)
legend()
=#

# (Periodic) orbit length: c is disk system, orbit is trajectory (e.g. [1, 2, 3, 1]), b0 is starting point on disk 1
function L(c, b0, orbit)
    l = 0
    b1 = b0
    for i = 1:length(orbit)-1
        l += distance(b1, c, orbit[i], orbit[i+1])
        b1 = T0(b1, c, orbit[i], orbit[i+1])
    end
    l
end


