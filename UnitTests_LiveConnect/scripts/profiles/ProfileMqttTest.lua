---@diagnostic disable: param-type-mismatch

-------------------------------------------------------------------------------------
-- Variables
local m_json = require("utils.Lunajson")
local m_timer = Timer.create()
local m_returnFunctions = {}
local m_mqttRegisteredFunctions = {}

-------------------------------------------------------------------------------------
-- Get UTC time according to RFC 3339
local function getTimestamp()
  local l_day, l_month, l_year, l_hour, l_minute, l_second, l_millisecond = DateTime.getDateTimeValuesUTC()
  local l_ret = string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
    ---@diagnostic disable-next-line: redundant-parameter
    l_year, l_month, l_day, l_hour, l_minute, l_second, l_millisecond)

  return l_ret
end

-------------------------------------------------------------------------------------
-- Publish MQTT payload
local function publishPayload(partNumber, serialNumber, updateTime_ms)
  local l_payload = {}
  l_payload.timestamp = getTimestamp()
  l_payload.index = math.random(0,255)
  l_payload.data = string.format("Random index value pushed from the edge side, updated every %sms", updateTime_ms)

  local l_payloadJson = m_json.encode(l_payload)
  CSK_LiveConnect.publishMQTTData("sick/device/mqtt-test", partNumber, serialNumber, l_payloadJson)
end

-------------------------------------------------------------------------------------
-- Start MQTT payload simulation
function m_returnFunctions.startPayloadSimulation(partNumber, serialNumber, updateTime_ms)
  if m_mqttRegisteredFunctions[partNumber .. serialNumber] ~= nil then
    m_returnFunctions.stopPayloadSimulation(partNumber, serialNumber)
  end

  m_mqttRegisteredFunctions[partNumber .. serialNumber] =
    function()
      return publishPayload(partNumber, serialNumber, updateTime_ms)
    end
  m_timer:setExpirationTime(updateTime_ms)
  m_timer:setPeriodic(true)
  m_timer:register("OnExpired", m_mqttRegisteredFunctions[partNumber .. serialNumber])
  m_timer:start()
end

-------------------------------------------------------------------------------------
-- Stop MQTT payload simulation
function m_returnFunctions.stopPayloadSimulation(partNumber, serialNumber)
  m_timer:stop()
  m_timer:deregister("OnExpired", m_mqttRegisteredFunctions[partNumber .. serialNumber])

  m_mqttRegisteredFunctions[partNumber .. serialNumber] = nil
end

-------------------------------------------------------------------------------------
-- Create MQTT profile
function m_returnFunctions.create()
  local l_mqttProfile = CSK_LiveConnect.MQTTProfile.create()
  CSK_LiveConnect.MQTTProfile.setUUID(l_mqttProfile, "55aa8083-24dc-41aa-bad0-ee28d5892d9d")
  CSK_LiveConnect.MQTTProfile.setName(l_mqttProfile, "LiveConnect MQTT test profile")
  CSK_LiveConnect.MQTTProfile.setDescription(l_mqttProfile, "Profile to test data push mechanism")
  CSK_LiveConnect.MQTTProfile.setBaseTopic(l_mqttProfile, "sick/device/mqtt-test")
  CSK_LiveConnect.MQTTProfile.setAsyncAPISpecification(l_mqttProfile, File.open("resources/profileMqttTest.yaml", "rb"):read())
  CSK_LiveConnect.MQTTProfile.setVersion(l_mqttProfile, "0.1.0")

  return l_mqttProfile
end

-------------------------------------------------------------------------------------
-- Return object
return m_returnFunctions