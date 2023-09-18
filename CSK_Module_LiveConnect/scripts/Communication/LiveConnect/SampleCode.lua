-------------------------------------------------------------------------------------
-- INFO
-- This is a sample code to show how this feature could be used e.g. out of other applications.
-- There are 2 different methods available: MQTT and HTTP.
-- Please check the following code lines to understand how to make use of them.
-- This script serves only as sample code and is not used within this CSK module.
-------------------------------------------------------------------------------------

-- Adapt accordingly
local m_json = require("utils.Lunajson")
local m_mqttProfileFilePath = "resources/profileMQTTTest.yaml"
local m_httpProfileFilePath = "resources/profileHTTPTest.yaml"


-- ##############################
-- ## MQTT profile (data push) ##
-- ##############################

-- Variables
local m_timer = Timer.create()

-------------------------------------------------------------------------------------
-- Payload to be sent at a specific interval
local function sendMQTTData(partNumber, serialNumber, topic)
  local l_payload = {}
  l_payload.timestamp = DateTime.getDateTime()
  l_payload.index = math.random(0,255)
  l_payload.data = "Payload from the edge side"

  local l_payloadJson = m_json.encode(l_payload)
  CSK_LiveConnect.publishMQTTData(topic, partNumber, serialNumber, l_payloadJson)
end

-------------------------------------------------------------------------------------
-- Add MQTT application profile
local function addNewMQTTProfile(partNumber, serialNumber)
  -- Profile definition
  local l_mqttProfile = CSK_LiveConnect.MQTTProfile.create()
  local l_topic = "sick/device/mqtt-test"
  l_mqttProfile:setUUID("55aa8083-24dc-41aa-bad0-ee28d5892d9d")
  l_mqttProfile:setName("LiveConnect MQTT test profile")
  l_mqttProfile:setDescription("Profile to test data push mechanism")
  l_mqttProfile:setBaseTopic(l_topic)
  l_mqttProfile:setAsyncAPISpecification(File.open(m_mqttProfileFilePath, "rb"):read())
  l_mqttProfile:setVersion("0.1.0")

  -- Payload definition
  local l_sendData = function()
    return sendMQTTData(partNumber, serialNumber, l_topic)
  end
  m_timer:setExpirationTime(5000)
  m_timer:setPeriodic(true)
  m_timer:register("OnExpired", l_sendData)
  m_timer:start()

  -- Register application profile
  CSK_LiveConnect.addMQTTProfile(partNumber, serialNumber, l_mqttProfile)
end
-------------------------------------------------------------------------------------
-- ######################
-- ## MQTT profile END ##
-- ######################
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- ##############################
-- ## HTTP profile (data poll) ##
-- ##############################
-------------------------------------------------------------------------------------
-- Respond to HTTP request
local function httpCallback(request)
  local l_response = CSK_LiveConnect.Response.create()
  local l_header = CSK_LiveConnect.Header.create()
  CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
  CSK_LiveConnect.Header.setValue(l_header, "application/json")

  l_response:setHeaders({l_header})
  l_response:setStatusCode(200)

  local l_responsePayload = {}
  l_responsePayload["timestamp"] = DateTime.getDateTime()
  l_responsePayload["index"] = math.random(0,255)
  l_responsePayload["data"] = "Response payload from the edge side"

  l_response:setContent(m_json.encode(l_responsePayload))
  return l_response
end

-------------------------------------------------------------------------------------
-- Add HTTP application profile
local function addNewHTTPProfile(partNumber, serialNumber)
  local l_httpProfile =  CSK_LiveConnect.HTTPProfile.create()
  l_httpProfile:setName("LiveConnect HTTP test profile")
  l_httpProfile:setDescription("Profile to test bi-direction communication between the server and the client")
  l_httpProfile:setVersion("0.2.0")
  l_httpProfile:setUUID("68f372d5-607c-4e16-b137-63af9fadaaa5")
  l_httpProfile:setOpenAPISpecification(File.open(m_httpProfileFilePath, "rb"):read())
  l_httpProfile:setServiceLocation("http-test")

  -- Endpoint definition
  local l_uri = "getwithoutparam"
  local l_crownName = Engine.getCurrentAppName() .. "." .. l_uri
  local l_endpoint = CSK_LiveConnect.HTTPProfile.Endpoint.create()
  l_endpoint:setHandlerFunction(l_crownName)
  l_endpoint:setMethod("GET")
  l_endpoint:setURI(l_uri)

  -- Register callback function, which will be called to answer the HTTP request
  Script.serveFunction(l_crownName, httpCallback, "object:CSK_LiveConnect.Request", "object:CSK_LiveConnect.Response")

  -- Add endpoints
  CSK_LiveConnect.HTTPProfile.setEndpoints(l_httpProfile, {l_endpoint})

  -- Register application profile
  CSK_LiveConnect.addHTTPProfile(partNumber, serialNumber, l_httpProfile)
end

-------------------------------------------------------------------------------------
-- ######################
-- ## HTTP profile END ##
-- ######################
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function handleOnClientInitialized()
  -- MQTT profile (data push)
  addNewMQTTProfile("1057651", "17410401") -- Part- and serial number of a SICK DT35 IO-Link device

  -- HTTP profile (data poll)
  addNewHTTPProfile("1057651", "17410401") -- Part- and serial number of a SICK DT35 IO-Link device
end
Script.register('CSK_LiveConnect.OnClientInitialized', handleOnClientInitialized)


