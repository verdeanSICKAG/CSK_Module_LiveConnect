-------------------------------------------------------------------------------------
-- Variables
local m_class = {}
local m_indend = "  "

-------------------------------------------------------------------------------------
-- Constants
local ORDER_ASYNC_API ={
  ["asyncapi"] = 1, ["info"] = 2, ["servers"] = 3, ["channels"] = 4, ["components"] = 5
}
local ORDER_OPEN_API ={
  ["openapi"] = 1, ["info"] = 2, ["jsonSchemaDialect"] = 3, ["servers"] = 4, ["paths"] = 5,
  ["webhooks"] = 6, ["components"] = 7, ["security"] = 8, ["tags"] = 9, ["externalDocs"] = 10
}

-------------------------------------------------------------------------------------
-- Status code should only have 3 digits
local function isArray(name)
  local l_isArray = false
  if type(name) == "number" then
    if name >= 100 and name <= 999 then
      l_isArray = false
    else
      l_isArray = true
    end
  end

  return l_isArray
end

-------------------------------------------------------------------------------------
-- Get array length
local function getArrayLength(data)
  local l_len = 0
  for _,_ in pairs(data) do
    l_len = l_len + 1
  end
  return l_len
end

-------------------------------------------------------------------------------------
-- Get property name + value
local function getProperty(name, value)
  local l_result = ""
  if type(name) ~= "number" then
    l_result = name .. ": "
  else
    -- Array
    l_result = "- "
  end

  if type(value) == "number" then
    l_result = l_result .. tostring(value)
  elseif type(value) == "string" then
    -- Replace quotation marks in the string
    local l_text = string.gsub(value, "\"", "\\\"")
    l_result = l_result .. "\"" .. l_text .. "\""
  elseif type(value) == "boolean" then
    l_result = l_result .. (value and "true" or "false")
  else
    l_result = "\"[inserializeable datatype:" .. type(value) .. "]"
  end

  return l_result
  
end

-------------------------------------------------------------------------------------
-- 
local function deserializeYaml(val, name , depth)
  -- -2 = The table itself
  -- -1 = Enumeration used for sorting the table
  --  0 = Content level 1
  depth = depth or -2

  local tmp = ""
  if type(val) == "table" then
    if name ~= nil then
      if depth >= 0 then
        -- Line indend
        tmp = string.rep(m_indend, depth)

        if isArray(name) then
          -- Array of object
          tmp = tmp .. "-" .. "\n"
        else
          if getArrayLength(val) <= 0 then
            -- Empty array
            tmp = tmp .. name .. ": []" .. "\n"
          else
            -- Property
            tmp = tmp .. name .. ": " .. "\n"
          end
        end
      end
    end

    -- Iterate over all table members
    for k, v in pairs(val) do
      local l_ser = deserializeYaml(v, k, depth + 1)
      tmp =  tmp .. l_ser
    end
  else
      local l_prop = getProperty(name, val)
      tmp = string.rep(m_indend, depth) .. l_prop .. "\n"
  end

  return tmp
end

-------------------------------------------------------------------------------------
-- Deserialize the LUA table and provide it as yaml data
function m_class.compose(yamlAsTable)
  local l_dataOrdered = {}
  local l_dataSorted ={}

  -- Re-order table elements
  for k,v in pairs(yamlAsTable) do
    if yamlAsTable["asyncapi"] ~= nil then
      l_dataOrdered[ORDER_ASYNC_API[k]] = {}
      l_dataOrdered[ORDER_ASYNC_API[k]][k] = v
    end
    if yamlAsTable["openapi"] ~= nil then
      l_dataOrdered[ORDER_OPEN_API[k]] = {}
      l_dataOrdered[ORDER_OPEN_API[k]][k] = v
    end
  end

  -- In some cases, it is necessary to re-ordered again 
  for i = 1, 20, 1 do
    if l_dataOrdered[i] then
      table.insert(l_dataSorted, l_dataOrdered[i])
    end
  end

  return deserializeYaml(l_dataSorted)
end

return m_class