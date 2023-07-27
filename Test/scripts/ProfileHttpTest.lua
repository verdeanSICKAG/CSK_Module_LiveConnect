---@diagnostic disable: param-type-mismatch, redundant-parameter
local m_json = require("utils.Lunajson")
local m_returnFunctions = {}


-------------------------------------------------------------------------------------
-- Get UTC time according to RFC 3339
local function getTimestamp()
  local l_day, l_month, l_year, l_hour, l_minute, l_second, l_millisecond = DateTime.getDateTimeValuesUTC()
  local l_ret = string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
    l_year, l_month, l_day, l_hour, l_minute, l_second, l_millisecond)

  return l_ret
end

-------------------------------------------------------------------------------------
-- Get a generated UUID
local function createUuid()
  local l_template ='xxxxxxxx'
  local l_uuid =  string.gsub(l_template, '[xy]', function (c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)

  return l_uuid
end

-------------------------------------------------------------------------------------
-- Respond to HTTP request
local function httpCallback(request)
  local l_response = CSK_LiveConnect.Response.create()
  local l_header = CSK_LiveConnect.Header.create()
  CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
  CSK_LiveConnect.Header.setValue(l_header, "application/json")

  l_response:setHeaders({l_header})
  l_response:setStatusCode(200)

  local l_index = 123
  local l_data = "No Payload received"
  if (request:getMethod() == "POST") then
    local l_requestPayload = m_json.decode(request:getContent())
    l_index = l_requestPayload.index
    l_data = l_requestPayload.data
  elseif (request:getMethod() == "GET") then
    print("GET request from URL: " .. request:getURL())
    local l_paraPos = string.find(request:getURL(), "index=")
    print(l_paraPos)
    l_index = tonumber(string.sub(request:getURL(), l_paraPos + 6, #request:getURL()))
  end
  local l_responsePayload = {}
  l_responsePayload["name"] = request:getMethod() .. " response from edge device"
  l_responsePayload["timestamp"] = getTimestamp()
  l_responsePayload["index"] = l_index
  l_responsePayload["data"] = l_data

  l_response:setContent(m_json.encode(l_responsePayload))

  return l_response
end

-------------------------------------------------------------------------------------
-- Get endpoint
local function getEndpoint(method, uri)
  local l_crownName = Engine.getCurrentAppName() .. "." .. createUuid()
  local l_endpoint = CSK_LiveConnect.HttpProfile.Endpoint.create()
  CSK_LiveConnect.HttpProfile.Endpoint.setHandlerFunction(l_endpoint, l_crownName)
  CSK_LiveConnect.HttpProfile.Endpoint.setMethod(l_endpoint, method)
  CSK_LiveConnect.HttpProfile.Endpoint.setURI(l_endpoint, uri)

  return l_endpoint
end

-------------------------------------------------------------------------------------
-- Register HTTP callback function
function m_returnFunctions.registerHttpFunction(profile)
  -- Serve functions for each HTTP endpoint
  for _,endpoint in pairs(CSK_LiveConnect.HttpProfile.getEndpoints(profile)) do
    local l_handlerFunction = endpoint:getHandlerFunction()
    Script.serveFunction(l_handlerFunction, httpCallback, "object:CSK_LiveConnect.Request", "object:CSK_LiveConnect.Response")
  end
end

-------------------------------------------------------------------------------------
-- Create HTTP profile
function m_returnFunctions.createHttpProfile()
  local l_httpProfile =  CSK_LiveConnect.HttpProfile.create()
  CSK_LiveConnect.HttpProfile.setName(l_httpProfile, "LiveConnect HTTP test profile")
  CSK_LiveConnect.HttpProfile.setDescription(l_httpProfile, "Profile to test bi-direction communication between the server and the client")
  CSK_LiveConnect.HttpProfile.setVersion(l_httpProfile, "0.1.0")
  CSK_LiveConnect.HttpProfile.setUuid(l_httpProfile, "55f372d5-607c-4e16-b137-63af9fadabb5")
  CSK_LiveConnect.HttpProfile.setOpenAPISpecification(l_httpProfile, File.open("resources/profileHttpTest.yaml", "rb"):read())
  CSK_LiveConnect.HttpProfile.setServiceLocation(l_httpProfile, "http-test")

  -- Endpoint definition
  local l_endpoints = {}
  table.insert(l_endpoints, getEndpoint("GET", "testget"))
  table.insert(l_endpoints, getEndpoint("POST", "testpost"))

  -- Add endpoints
  CSK_LiveConnect.HttpProfile.setEndpoints(l_httpProfile, l_endpoints)

  return l_httpProfile
end

-------------------------------------------------------------------------------------
-- Return object
return m_returnFunctions