#coding=gbk
from sympy import symbols, exp, integrate, simplify

# Define symbols
y, x, m, n, theta = symbols('y x m n theta')

# First integral
first_integral = integrate((m*y - n*(x - y)) * (1/theta) * exp(-y/theta), (y, 0, x))

# Second integral
#second_integral = integrate(m*x * (1/theta) * exp(-y/theta), (y, x, 'oo'))
simplified_second_integral = m * x * exp(-x/theta)

# Combine the results
#total_integral = first_integral  + second_integral
total_integral = first_integral  + simplified_second_integral

# Simplify the expression
simplified_expr = simplify(total_integral)

print(simplified_expr)




