---@diagnostic disable: param-type-mismatch
local m_json = require("utils.Lunajson")
local m_payloadValue1 = 0
local m_payloadValue2 = 0
local m_timer = Timer.create()
local m_returnFunctions = {}
local m_mqttRegisteredFunctions = {}

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
-- Publish MQTT payload
local function publishMqttPayload(partNumber, serialNumber)
  local l_payload = {}
  l_payload.distance = m_payloadValue1
  l_payload.unit = "mm"
  l_payload.timestamp = getTimestamp()
  m_payloadValue1 = m_payloadValue1 + 1

  local l_payloadJson = m_json.encode(l_payload)
  CSK_LiveConnect.publishMqttData("sick/device/distance-data", partNumber, serialNumber, l_payloadJson)
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

  local l_payload = {}
  l_payload["distanceData"] = m_payloadValue2
  m_payloadValue2 = m_payloadValue2 + 1
  l_payload["unit"] = "mm"

  l_response:setContent(m_json.encode(l_payload))
  return l_response
end

-------------------------------------------------------------------------------------
-- Start MQTT payload simulation
function m_returnFunctions.startMqttPayloadSimulation(partNumber, serialNumber)
  print("start MQTT payload simulation")
  m_mqttRegisteredFunctions[partNumber .. serialNumber] =
    function()
      return publishMqttPayload(partNumber, serialNumber)
    end
  m_timer:setExpirationTime(5000)
  m_timer:setPeriodic(true)
  m_timer:register("OnExpired", m_mqttRegisteredFunctions[partNumber .. serialNumber])
  m_timer:start()
end

-------------------------------------------------------------------------------------
-- Stop MQTT payload simulation
function m_returnFunctions.stopMqttPayloadSimulation(partNumber, serialNumber)
  m_timer:deregister("OnExpired", m_mqttRegisteredFunctions[partNumber .. serialNumber])
  m_timer:stop()
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
-- Add HTTP endpoint
function m_returnFunctions.createHttpProfile()
  local l_httpProfile =  CSK_LiveConnect.HttpProfile.create()
  CSK_LiveConnect.HttpProfile.setName(l_httpProfile, "Distance Data")
  CSK_LiveConnect.HttpProfile.setDescription(l_httpProfile, "Distance data profile")
  CSK_LiveConnect.HttpProfile.setVersion(l_httpProfile, "0.0.1")
  CSK_LiveConnect.HttpProfile.setUuid(l_httpProfile, "39cc68c9-ee05-4196-8717-584e1d57efd9")
  CSK_LiveConnect.HttpProfile.setOpenAPISpecification(l_httpProfile, File.open("resources/profileHttpDistanceData.yaml", "rb"):read())
  CSK_LiveConnect.HttpProfile.setServiceLocation(l_httpProfile, "distance-data")

  local l_endpoints = {}
  local crownName = Engine.getCurrentAppName() .. "." .. createUuid()
  local l_endpoint = CSK_LiveConnect.HttpProfile.Endpoint.create()
  CSK_LiveConnect.HttpProfile.Endpoint.setHandlerFunction(l_endpoint, crownName)
  CSK_LiveConnect.HttpProfile.Endpoint.setMethod(l_endpoint, "GET")
  CSK_LiveConnect.HttpProfile.Endpoint.setURI(l_endpoint, "data")
  table.insert(l_endpoints, l_endpoint)
  CSK_LiveConnect.HttpProfile.setEndpoints(l_httpProfile, l_endpoints)

  return l_httpProfile
end

-------------------------------------------------------------------------------------
-- Create MQTT profile
function m_returnFunctions.createMqttProfile()
  local l_mqttProfile = CSK_LiveConnect.MqttProfile.create()
  CSK_LiveConnect.MqttProfile.setUuid(l_mqttProfile, "66bb8083-24dc-41aa-bad0-ee28d5892d9d")
  CSK_LiveConnect.MqttProfile.setName(l_mqttProfile, "Distance Data")
  CSK_LiveConnect.MqttProfile.setDescription(l_mqttProfile, "Distance data profile")
  CSK_LiveConnect.MqttProfile.setBaseTopic(l_mqttProfile, "sick/device/distance-data")
  CSK_LiveConnect.MqttProfile.setAsyncAPISpecification(l_mqttProfile, File.open("resources/profileMqttDistanceData.yaml", "rb"):read())
  CSK_LiveConnect.MqttProfile.setVersion(l_mqttProfile, "0.0.1.1000A")

  return l_mqttProfile
end

-------------------------------------------------------------------------------------
-- Return object
return m_returnFunctions