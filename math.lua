-- math-related functions

-- convert binary string to number
function math.bin(n)
  return tonumber(n, 2)
end

-- convert octal string to number
function math.oct(n)
	return tonumber(n, 8)
end

-- convert hex string to number
function math.hex(n)
  return tonumber(n, 16)
end

-- degree-based trig:
-- dcos dsin dtan dacos dasin datan
for k,v in ipairs({ "cos", "sin", "tan", "tan2" }) do
	math["d"..v] = function(r) return math[v](math.rad(r)) end
	math["da"..v] = function(r) return math.deg(math["a"..v](r)) end
end
math.dtan2 = nil

function math.bound(min, n, max)
  return math.max(
    math.min(n, max),
    min)
end
