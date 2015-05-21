-- printf(format, ...)
function printf(...)
  return io.stdout:printf(...)
end

-- printf to standard error
function eprintf(...)
  return io.stderr:printf(...)
end

-- bind to io tables, so that file:printf(...) becomes legal
getmetatable(io.stdout).__index.printf = function(self, ...)
  return self:write(string.format(...))
end

function io.readfile(name)
  local fd = assert(io.open(name, "rb"))
  local buf = fd:read("*a")
  fd:close()
  return buf
end

function io.writefile(name, data)
  local fd = assert(io.open(name, "wb"))
  fd:write(data)
  fd:close()
end

function io.exists(name, mode)
  local fd = io.open(name, mode or 'r')
  if fd then
    fd:close()
    return true
  end
end
