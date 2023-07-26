---@diagnostic disable: param-type-mismatch
local m_json = require("utils.Lunajson")
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
-- Publish MQTT payload
local function publishMqttPayload(partNumber, serialNumber)
  local l_payload = {}
  l_payload.timestamp = getTimestamp()
  l_payload.vendorName = "Verdenhalven inc."
  l_payload.productName = "My fancy product"
  l_payload.productId = partNumber
  l_payload.serialNumber = serialNumber


  local l_payloadJson = m_json.encode(l_payload)
  CSK_LiveConnect.publishMqttData("sick/iolink/identdata", partNumber, serialNumber, l_payloadJson)
end

-------------------------------------------------------------------------------------
-- Start MQTT payload simulation
function m_returnFunctions.startMqttPayloadSimulation(partNumber, serialNumber)
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
-- Create MQTT profile
function m_returnFunctions.createMqttProfile()
  local l_mqttProfile = CSK_LiveConnect.MqttProfile.create()
  CSK_LiveConnect.MqttProfile.setUuid(l_mqttProfile, "1afb5af2-b1ca-4e6c-9837-c96121fe0c96")
  CSK_LiveConnect.MqttProfile.setName(l_mqttProfile, "IO-Link Device Identification")
  CSK_LiveConnect.MqttProfile.setDescription(l_mqttProfile, "IO-Link device identification data")
  CSK_LiveConnect.MqttProfile.setBaseTopic(l_mqttProfile, "sick/iolink/identdata")
  CSK_LiveConnect.MqttProfile.setAsyncAPISpecification(l_mqttProfile, File.open("resources/profileMqttIdentification.yaml", "rb"):read())
  CSK_LiveConnect.MqttProfile.setVersion(l_mqttProfile, "0.0.1.202205251000A")

  return l_mqttProfile
end

-------------------------------------------------------------------------------------
-- Return object
return m_returnFunctions