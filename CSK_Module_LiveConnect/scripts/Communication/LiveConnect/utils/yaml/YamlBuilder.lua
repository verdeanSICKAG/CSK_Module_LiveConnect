-------------------------------------------------------------------------------------
-- Variables
local m_class = {}
local m_yamlParser = require("Communication.LiveConnect.utils.yaml.YamlParser")
local m_yamlComposer = require("Communication.LiveConnect.utils.yaml.YamlComposer")

-------------------------------------------------------------------------------------
-- Constants
local TEMPLATE_ASYNC_API = "resources/profiles/templates/asyncApi.yaml"
local TEMPLATE_OPEN_API = "resources/profiles/templates/openApi.yaml"

-------------------------------------------------------------------------------------
-- Create async api file
local function createAsyncApi(title, description, endpoint, properties)
  -- Open template
  local l_file = File.open(TEMPLATE_ASYNC_API, "rb")
  local l_content = l_file:read()
  l_file:close()

  -- Serialize template
  local l_documentAsTable = m_yamlParser.parse(l_content, false)

  -- Update profile info
  l_documentAsTable.info.title = title
  l_documentAsTable.info.description = description
  l_documentAsTable.info.version = "1.0.0"

  -- Update channels
  -- TODO endpoint ...
  local l_topic = string.gsub(endpoint, " ", "-")
  l_documentAsTable.channels["sick/generic/" .. l_topic .. "/{deviceId}"] = l_documentAsTable.channels["sick/generic/{deviceId}"]
  l_documentAsTable.channels["sick/generic/{deviceId}"] = nil

  -- Add properties
  l_documentAsTable["components"]["schemas"]["GenericPayload"]["properties"] = properties

  -- Deserialize yaml table
  local l_resultYaml = m_yamlComposer.compose(l_documentAsTable)

  return l_resultYaml
end

-------------------------------------------------------------------------------------
-- Create open api file
local function createOpenApi(title, description, endpoint, properties)
  -- Open template
  local l_file = File.open(TEMPLATE_OPEN_API, "rb")
  local l_content = l_file:read()
  l_file:close()

  -- Serialize template
  local l_documentAsTable = m_yamlParser.parse(l_content, false)

  -- Update profile info
  l_documentAsTable.info.title = title
  l_documentAsTable.info.description = description
  l_documentAsTable.info.version = "1.0.0"

  -- Update server url
  -- TOD check url ...
  local l_relativeUrl = string.gsub(title, " ", "-")
  l_documentAsTable.servers[1]["url"] = l_documentAsTable.servers[1]["url"] .. "/" .. l_relativeUrl

  -- Update path 
  -- TODO check endpoint ...
  local l_endpoint = "/" .. endpoint
  l_documentAsTable["paths"][l_endpoint] = l_documentAsTable["paths"]["/endpoint"]
  l_documentAsTable["paths"]["/endpoint"] = nil

  -- Update endpoint tag
  l_documentAsTable["paths"][l_endpoint]["get"]["tags"][1] = title

  -- Update endpoint descripton
  l_documentAsTable["paths"][l_endpoint]["get"]["description"] = description

  -- Add properties
  if properties then
    l_documentAsTable["paths"][l_endpoint]["get"]["responses"][200]["content"]["application/json"]["schema"]["properties"] = properties
  end

  -- Deserialize yaml table and provide it as a string
  local l_resultYaml = m_yamlComposer.compose(l_documentAsTable)

  return l_resultYaml
end

-------------------------------------------------------------------------------------
-- Creates properties according to the YAML standard  
function m_class.createProperties(dataTable)
  local l_properties = {}
  for name,value in pairs(dataTable) do
    local l_dataType = type(value)
    if l_dataType == "table" then
      l_properties[name] = {}
      l_properties[name].type = "object"
      l_properties[name].properties = m_class.createProperties(value)
    elseif l_dataType == "boolean" then
      l_properties[name] = {}
      l_properties[name].type = "boolean"
    elseif l_dataType == "number" then
      l_properties[name] = {}
      l_properties[name].type = "number"
    elseif l_dataType == "string" then
      l_properties[name] = {}
      l_properties[name].type = "string"
    else
      error(string.format("Data type not supported[%s]", l_dataType))
    end
  end

  return l_properties
end

-------------------------------------------------------------------------------------
-- Create a yaml file with the given information
function m_class.createYaml(type, title, description, endpoint, data)
  local l_result = ""
  if type == "ASYNC_API" then
    l_result = createAsyncApi(title, description, endpoint, data)
  elseif type == "OPEN_API" then
    l_result = createOpenApi(title, description, endpoint,  data)
  else
    error(string.format("Yaml type not supported [%s]", type))
  end

  return l_result
end

return m_class