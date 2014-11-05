## Kicked rotor: periodic orbits calculation
# x is a vector (x[1], x[2]) = (x, p)

using KrawczykMethod2D

# Base function for the kicked rotor, x[1] is x, x[2] is p
f(x, K) = [(x[1] + K*sin(x[1]) + x[2]), (K*sin(x[1]) + x[2])] # % 2pi doesn't work yet

# Function composition while keeping K arbitrary
compose(f::Function, g::Function) = (x, K) -> f(g(x, K), K)

# T^n (x) function - T(T(T(...T(x)))) n times
function T(x, K, n)
	F = f
	for i = 1:n-1
		F = compose(F, f)
	end
	return F(x, K)
end

# n-periodic points equation
h(x, K, n) = T(x, K, n) - x

# Function to output zeros of n-th order given the K and the limits (x1, x2) and (p1, p2)
zeros(K, n, x1, x2, p1, p2, precision) = krawczyk2d(x -> h(x, K, n), [Interval(x1, x2), Interval(p1, p2)], precision)