import math

q96 = 2**96


def price_to_sqrtp(p):
    return int(math.sqrt(p) * q96)


def price_to_tick(p):
    return math.floor(math.log(p, 1.0001))


print("tick at 4545:", price_to_tick(4545))
print("tick at 5000:", price_to_tick(5000))
print("tick at 5500:", price_to_tick(5500))

print("q64.96(4545):", price_to_sqrtp(4545))
print("q64.96(5000):", price_to_sqrtp(5000))
print("q64.96(5500):", price_to_sqrtp(5500))
