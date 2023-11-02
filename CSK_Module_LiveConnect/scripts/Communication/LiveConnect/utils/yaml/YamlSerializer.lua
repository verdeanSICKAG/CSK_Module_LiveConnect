-------------------------------------------------------------------------------------
-- Variables
local m_class = {}
local m_tinyYaml = require("Communication.LiveConnect.utils.yaml.Tinyyaml")

-------------------------------------------------------------------------------------
-- Checks if a string ends with the with given characters
local function isStringEndsWith(str, comp)
  if type(str) == "string" then
    return str:sub(#str - #comp + 1, #str) == comp
  else
    return false
  end
end

-------------------------------------------------------------------------------------
-- Splits string function. Splits a string by a given separator
local function stringSplit(inputstr, seperator)
  local l_result = {}
  if seperator == nil then
    seperator = "%s"
  end

  for l_strPart in string.gmatch(inputstr, "([^" .. seperator .. "]+)") do
    table.insert(l_result, l_strPart)
  end
  return l_result
end

-------------------------------------------------------------------------------------
-- Get table value by scope
local function getTableValueByScope(path, dataFull)
    local l_pathParts = stringSplit(path, "/")
    table.remove(l_pathParts, 1) -- remove first entry "#"
    local l_enteredPaths = ""

    local l_curLocation = dataFull
    for i=1, #l_pathParts do
        if (l_curLocation[l_pathParts[i]] == nil) then
            print("Entry \"" .. l_pathParts[i] .. "\" in \"" .. l_enteredPaths .. "\", does not exist.")
            return nil
        end
        -- If last value in l_pathParts
        if (i == #l_pathParts) then 
            return l_curLocation[l_pathParts[i]]
        else
            l_curLocation = l_curLocation[l_pathParts[i]]
            l_enteredPaths = l_enteredPaths .. l_pathParts[i] .. "/"
        end
    end

    return l_curLocation
end

-------------------------------------------------------------------------------------
-- Copy and resolve table
local function resolveTable(dataPart, dataFull, resolveRefs)
  local l_resolvedYaml = {}
  for k, v in pairs(dataPart) do
		if type(v) == "table" then
      local l_resolvedTable = resolveTable(v, dataFull, resolveRefs)
      l_resolvedYaml[k] = l_resolvedTable
		else
      if k =="$ref" and resolveRefs then
        local l_tableReference = resolveTable(getTableValueByScope(v, dataFull), dataFull, resolveRefs)
        l_resolvedYaml = l_tableReference
      else
        -- Remove \x0A (\n) at the end of a string
        if isStringEndsWith(v, "\n") then
          l_resolvedYaml[k] = string.sub(v, 1, #v -1);
        else
          l_resolvedYaml[k] = v;
        end
      end
		end
	end

  return l_resolvedYaml
end

function m_class.serialize(yamlData, resolveReferences)
  -- Parse yaml
  local l_yamlAsTable = m_tinyYaml.parse(yamlData)

  -- Resolve references
  l_yamlAsTable = resolveTable(l_yamlAsTable, l_yamlAsTable, resolveReferences)

  -- Remove "components" if exist
  if resolveReferences == true then
    l_yamlAsTable["components"] = nil
  end

  return l_yamlAsTable
end

return m_class