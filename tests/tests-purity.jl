## Interval purity w.r.t. a test function in 1D and 2D - new version with the new type

using IntervalArithmetic
using PurityIntervals
using FactCheck
# Test function sqrt1(1 - x^2)

function test_domains1d(f)

	x1 = -1.5; x2 = -1.3; x3 = -1; x4 = 0.3; x5 = 0.5; x6 = 1; x7 = 1.3; x8 = 1.5

	clean1 = Interval(x4, x5)
    clean2 = Interval(x4, x6)
	clean3 = Interval(x3, x5)
	clean4 = Interval(x3, x6)

	unclean1 = Interval(x4, x7)
	unclean2 = Interval(x2, x5)

	dirty1 = Interval(x1, x2)
	dirty2 = Interval(x7, x8)

  facts("1D tests") do
	@fact purity(f, clean1) == 1 --> true
	@fact purity(f, clean2) == 1 --> true
	@fact purity(f, clean3) == 1 --> true
	@fact purity(f, clean4) == 1 --> true

	@fact purity(f, unclean1) == 0 --> true
	@fact purity(f, unclean2) == 0 --> true

	@fact purity(f, dirty1) == -1 --> true
	@fact purity(f, dirty2) == -1 --> true
  end
end

f1(x) = sqrt(1 - x^2)
println("Testing 1D sqrt(1-x^2)....................")
test_domains1d(f1)
println("Testing 1D arcsin....................")
test_domains1d(asin)

# Testing another function with domain (-sin 1, sin 1), so clean2 - clean4 will be unclean
println("Testing 1D sqrt(1 - arcsin^2 x)....................")
f2(x) = sqrt(1 - (asin(x))^2)
x1 = -1.5; x2 = -1.3; x3 = -1; x4 = 0.3; x5 = 0.5; x6 = 1; x7 = 1.3; x8 = 1.5
clean1 = Interval(x4, x5)
clean2 = Interval(x4, x6)
clean3 = Interval(x3, x5)
clean4 = Interval(x3, x6)
unclean1 = Interval(x4, x7)
unclean2 = Interval(x2, x5)
dirty1 = Interval(x1, x2)
dirty2 = Interval(x7, x8)
@show purity(f2, clean1) == 1
@show purity(f2, clean2) == 0
@show purity(f2, clean3) == 0
@show purity(f2, clean4) == 0
@show purity(f2, unclean1) == 0
@show purity(f2, unclean2) == 0
@show purity(f2, dirty1) == -1
@show purity(f2, dirty2) == -1

## 2D functions and intervals

f3(x) = [sqrt(1 - x[1]^2)*asin(x[2]), x[1]*x[2]]

clean = [Interval(-0.4, 0.6), Interval(0.3, 0.8)]
unclean1 = [Interval(-1.2, 0.6), Interval(0.3, 0.8)]
unclean2 = [Interval(0.6, 1.2), Interval(0.3, 0.8)]
unclean3 = [Interval(0.6, 0.8), Interval(-1.2, -0.7)]
unclean4 = [Interval(0.6, 0.8), Interval(0.8, 1.2)]
unclean5 = [Interval(-1.2, -0.5), Interval(0.8, 1.2)]
dirty1 = [Interval(-1.5, -1.2), Interval(-1.5, -1.2)]
dirty2 = [Interval(-1.5, -1.2), Interval(1.2, 1.5)]
dirty3 = [Interval(1.2, 1.5), Interval(-1.5, -1.2)]
dirty4 = [Interval(1.2, 1.5), Interval(1.2, 1.5)]


function test_domains2d(f)

	@show purity(f, clean) == 1
	@show purity(f, unclean1) == 0
	@show purity(f, unclean2) == 0
	@show purity(f, unclean3) == 0
	@show purity(f, unclean4) == 0
	@show purity(f, unclean5) == 0
	@show purity(f, dirty1) == -1
	@show purity(f, dirty2) == -1
	@show purity(f, dirty3) == -1
	@show purity(f, dirty4) == -1

end

println("Testing 2D sqrt(1 - x[1]^2)*arcsin(x[2]) with purity....................")
test_domains2d(f3)

function test_domains2d_1(f)

	@show purity(f, clean) == 1
	@show purity(f, unclean1) == 0
	@show purity(f, unclean2) == 0
	@show purity(f, unclean3) == 0
	@show purity(f, unclean4) == 0
	@show purity(f, unclean5) == 0
	@show purity(f, dirty1) == -1
	@show purity(f, dirty2) == -1
	@show purity(f, dirty3) == -1
	@show purity(f, dirty4) == -1

end

println("Testing 2D sqrt1(1 - x[1]^2)*arcsin(x[2]) with purity....................")
test_domains2d_1(f3)

# Function where the variables are coupled
f4(x) = [sqrt(1 - (x[1]*x[2])^2)*asin(x[2] - x[1]), x[1]*x[2]]

clean1 = [Interval(-0.4, 0.4), Interval(-0.4, 0.4)]
clean2 = [Interval(-1, -0.6), Interval(-0.7, -0.4)]
unclean1 = [Interval(-1, 0), Interval(-1.2, -0.8)]
unclean2 = [Interval(0, 1), Interval(-0.4, 0.3)]
dirty1 = [Interval(0, 1), Interval(-1.6, -1.4)]
dirty2 = [Interval(1.2, 2), Interval(1.2, 2.1)]

println("Testing 2D sqrt(1 - (x[1]*x[2])^2)*arcsin(x[2] - x[1]) with purity....................")
@show purity(f4, clean1) == 1
@show purity(f4, clean2) == 1
@show purity(f4, unclean1) == 0
@show purity(f4, unclean2) == 0
@show purity(f4, dirty1) == -1
@show purity(f4, dirty2) == -1


println("Testing 2D sqrt(1 - (x[1]*x[2])^2)*arcsin(x[2] - x[1]) with purity....................")
@show purity(f4, clean1) == 1
@show purity(f4, clean2) == 1
@show purity(f4, unclean1) == 0
@show purity(f4, unclean2) == 0
@show purity(f4, dirty1) == -1
@show purity(f4, dirty2) == -1

println("Testing arcsin(x - y)............................")
f5(x) = [asin(x[1] - x[2]), x[1]*x[2]]
clean = [Interval(-0.5, 0.5), Interval(-0.5, 0.5)]
unclean = [Interval(0, 2), Interval(0, 2)]
dirty = [Interval(1.5, 2), Interval(-2, -1.5)]
@show purity(f5, clean) == 1
@show purity(f5, unclean) == 0
@show purity(f5, dirty) == -1

