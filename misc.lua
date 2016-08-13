-- Assorted global functions that don't belong in their own file.

-- 5.3 compatibility
local unpack = unpack or table.unpack
local loadstring = loadstring or load

-- "safe require", returns nil,error if require fails rather than
-- throwing an error
function srequire(...)
	local s,r = pcall(require, ...)
	if s then
		return r
	end
	return nil,r
end

-- fast one-liner lambda creation
function f(src)
	return assert(loadstring(
		"return function(" .. src:gsub(" => ", ") return ") .. " end"
	))()
end

-- bind args into function
function partial(f, ...)
	if select('#', ...) == 0 then
		return f
	end
	local head = (...)
	return partial(function(...) return f(head, ...) end, select(2, ...))
end

-- New versions of pairs, ipairs, and type that respect the corresponding
-- metamethods.
do
	local function metamethod_wrap(f, name)
		return function(v)
			local mm = getmetafield(v, name)
			if mm then
				return mm(v)
			end
			return f(v)
		end
	end
	rawtype = type
	type = metamethod_wrap(type, "__type")

	-- We only need this on Lua 5.1 (5.2+ have it built in). But LuaJIT may also
	-- have it built in, depending on compilation option.
	-- If jit is not defined, we're running in stock 5.1. If it is, but so is
	-- math.mod, we're running luajit without 5.2 extensions (turning on the
	-- extensions removes math.mod). In either case we need to enable this.
	if _VERSION:match("Lua 5.1") and (not jit or math.mod) then
		pairs = metamethod_wrap(pairs, "__pairs")
		ipairs = metamethod_wrap(ipairs, "__ipairs")
	end
end

-- formatting-aware versions of assert and error
do
	-- We call it 'assertf' because things like assert(call()) are common, and
	-- if call() returns a bunch of stuff format() will get confused.
	-- This is more for 'assert(precondition, error, ...)' style usage.
	-- Maybe it should be called check() instead?
	function assertf(exp, err, ...)
		return assert(exp, err:format(...))
	end

	local _error = error
	function error(err, ...)
		if select('#', ...) > 0 then
			return _error(err:format(...))
		end
		return _error(err)
	end
end

-- Get field from metatable, return nil if no metatable
function getmetafield(v, k)
	local mt = getmetatable(v)
	return mt and rawget(mt, k)
end

-- As tonumber/tostring, but casts to bool
function toboolean(v)
	return not not v
end
