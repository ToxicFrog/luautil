--[[
flags.register("v", "verbose")
flags.register("x", "extract") {
  key = "mode";
}
flags.register("l", "list") {
  key = "mode";
}
flags.register("r", "res") {
  type = flags.list;
}

Default type is boolean, meaning that -f --foo (set) +f --no-foo (unset) are
valid.

If type is anything other than boolean, it requires an argument, e.g. -f bar
or --foo=bar.

All equivalent, if foo requires an argument:
  -f bar
  -fbar
  --foo bar
  --foo=bar
]]

flags = {
  registered = {};
  defaults = {};
  name = (arg and arg[0]) or "(unknown)";
  max_length = 0;
}
flags.parsed = flags.defaults

local function asId(str)
  return (str:gsub("^(%d)", "_%1"):gsub("%W", "_"))
end

function flags.register(...)
  local aliases = {...}
  assert(#aliases > 0, "no arguments provided to flags.register")

  local flag = {}
  flag.key = asId(aliases[1])
  flag.help = ""
  flag.name = (#aliases[1] == 1 and "-%s" or "--%s"):format(aliases[1])
  flag.type = flags.boolean
  flag.aliases = aliases
  for _,alias in ipairs(aliases) do
    assert(not flags.registered[alias], "Flag '"..alias.."' defined in multiple places!")
    flags.registered[alias] = flag
    flags.max_length = math.max(flags.max_length, #alias)
  end
  flags.registered[flag.key] = flag

  return flags.configure(flag)
end

function flags.configure(flag)
  return function(init)
    for k,v in pairs(init) do
      flag[k] = v
    end
    if flag.type ~= flags.boolean then
      flag.needs_value = true
    end
    if flag.default ~= nil then
      flags.defaults[flag.key] = flag.default
    end
    assert(not (flag.default ~= nil and flag.required), "Required flags must not have default values")
    assert(not (flag.default ~= nil and flag.key ~= asId(flag.aliases[1])),
      "Can't set both key= and default= on the same flag; set the default on the flag the key points at instead")
  end
end

function flags.help()
  local seen = {}
  local template = string.format("%%%ds  %%s", flags.max_length + 4)
  for k,v in pairs(flags.registered) do
    if not seen[v] then
      seen[v] = true
      io.write(template:format("", v.help.."\r"))
      for _,alias in ipairs(v.aliases) do
        io.write(template:format((#alias == 1 and "-" or "--")..alias, "\n"))
      end
    end
  end
end

local function setFlag(info, value)
  assert(value ~= nil, "Flag '"..info.name.."' requires an argument, but none was provided")

  if info.value ~= nil then
    value = info.value
  end
  value = info.type(info.name, value)
  flags.parsed[info.key] = value

  if info.set then
    info.set(info.key, value)
  end
end

local function appendArg(value)
  table.insert(flags.parsed, value)
end

-- Parse a long option with associated value, e.g. --log-level=debug; the
-- first argument is the flag name, the second everything after the =.
local function parseLongWithValue(arg)
  local flag,value = arg:match("^%-%-([^=]+)=(.*)")
  if not flag then return false end

  local invert = false
  if flag:match("^no%-") then
    flag = flag:sub(4)
    invert = true
  end
  local info = flags.registered[flag]

  if not info then
    assert(false, "unrecognized option '"..flag.."'")
    return false
  end
  assert(info.needs_value, "option '--"..flag.."' doesn't allow an argument")
  assert(not invert, "option '--"..flag.."' requires an argument and cannot be inverted with --no")

  setFlag(info, value)
  return true
end

-- Parse a long option with no attached value.
local function parseLong(arg, next)
  local flag = arg:match("^%-%-(..+)")
  if not flag then return false end

  local invert = false
  if flag:match("^no%-") then
    flag = flag:sub(4)
    invert = true
  end
  local info = flags.registered[flag]

  if not info then
    assert(false, "unrecognized option '--"..flag.."'")
    return false
  elseif not info.needs_value then
    setFlag(info, not invert)
    return true
  end
  assert(not invert, "option '--"..flag.."' requires an argument and cannot be inverted with --no")

  setFlag(info, next())
  return true
end

-- Parse a short option or a block of short options, e.g. -tvf or -o foo.
local function parseShort(arg, next)
  local invert,arg = arg:match("^([-+])(.+)")
  if not invert then return false end

  invert = invert == "+"

  for flag,idx in arg:gmatch("(.)()") do
    local info = flags.registered[flag]
    if not info then
      assert(false, "unrecognized option '-"..flag.."'")
    elseif info.needs_value then
      assert(not invert, "option '-"..flag.."' requires an argument and cannot be inverted with +")

      -- Flag with required argument; everything here after the flag is the
      -- argument.
      local val = arg:sub(idx)
      if #val == 0 then val = next() end

      setFlag(info, val)
      return true
    else
      -- Boolean flag; its mere presence or absense sets it.
      setFlag(info, not invert)
    end
  end
  return true
end

local function parsePositional(arg)
  appendArg(arg)
  return true
end

local function parseOne(arg, next)
  if arg == "--" then
    -- signifies end of flags; everything after this is a positional even if it
    -- looks like a flag.
    for arg in next do
      -- FIXME append to argv
    end
  else
    return parseLongWithValue(arg, next)
      or parseLong(arg, next)
      or parseShort(arg, next)
      or parsePositional(arg, next)
  end
end

local function parseArgs(undefok, argv)
  flags.parsed = setmetatable({}, { __index = flags.defaults })

  local i = 0
  local function next_arg()
    i = i+1
    return argv[i]
  end

  -- parse command line arguments
  for arg in next_arg do
    parseOne(arg, next_arg)
  end

  -- check that all mandatory arguments are provided
  for _,info in pairs(flags.registered) do
    if info.required then
      assert(flags.parsed[info.key] ~= nil,
             "Required command line flag '"..info.name.."' was not provided.")
    end
  end

  return flags.parsed
end

function flags.parse(...)
  return parseArgs(false, {...})
end

function flags.parsePartial(...)
  return parseArgs(true, {...})
end

function flags.require(key)
  local info = flags.registered[key]
  if not info then
    error("attempt to require unknown option '"..key.."'")
  end
  local value = rawget(flags.parsed, key)
  return assert(value ~= nil, "required option '"..info.name.."' not specified")
end

function flags.get(key)
  return flags.parsed[key]
end
setmetatable(flags, {
  __call = function(self, name)
    return flags.parsed[
      assert(flags.registered[name],
        "Attempt to access unknown command line flag '"..name.."'")
      .key
    ]
  end;
})

--
-- Type functions. These are used as values to the .type property of a flag
-- definition; when the flag is set, the value on the command line is passed
-- to the type function, which returns the value that should be stored.
-- This is where converting (e.g.) "1,2,3" to { 1, 2, 3 } happens.
--

function flags.boolean(flag, arg)
  -- As a special case, flags.boolean is passed either true or false
  return arg
end

function flags.string(flag, arg)
  return arg
end

function flags.number(flag, arg)
  return (assert(tonumber(arg), "option '"..flag.."' requires a numeric argument"))
end

-- listOf is a type function constructor; it's used as (e.g.)
--   type = flags.listOf(flags.number, ",")
function flags.listOf(type, separator)
  return function(flag, arg)
    local vals = {}
    local start = 1
    for stop in function() return arg:find(separator, start, true) end do
      table.insert(vals, type(flag, arg:sub(start, stop-1)))
      start = stop+1
    end
    table.insert(vals, type(flag, arg:sub(start)))
    return vals
  end
end

-- This covers the most common case (comma-separated list of strings).
flags.list = flags.listOf(flags.string, ",")
