---@diagnostic disable: duplicate-set-field
--[[
=====================================================================================
Description:
This unit test establishes a paring between the device and the digital twin in the 
AssetHub.The corresponding asset must already exist in the AssetHub. The pairing 
token is given as the parameter "token" when the test is started. A peer device is 
automatically added to the gateway device. An HTTP and an MQTT profile are added to 
both devices (gateway and peer device). After the unit test has been successfully
completed, the functionality must be checked using the checklist.

Please use the checklist to check if everything works as expected. 
The unit tests can be started via an HTTP REST call (POST) or with a standard crown
call.

=====================================================================================
HTTP REST call to start the unit tests:
URL = {{device-url}}/api/crown/UnitTests_LiveConnect/runTests
Body = 
{
    "data": {
        "token": "" // Empty string = Use an already existing pairing
    }
}

=====================================================================================
Hint:
The test classes are executed in alphabetical order.
The test cases do not really have a unit test character, but are a mixture of unit
tests and integration tests.

=====================================================================================
--]]

-------------------------------------------------------------------------------------
-- Variables
local m_lu = require('utils/LuaUnit')
local m_httpProfile = require('profiles/ProfileHttpTest')
local m_mqttProfile = require('profiles/ProfileMqttTest')
local m_params = {}
local m_numRegisteredHttpProfilesExpected
TestClass = {}

-------------------------------------------------------------------------------------
-- Constant values
local WATCHDOG_MS = 15000
local PEER_DEVICE = {partNumber = "1057651", serialNumber = "UNITTEST"}
local QUERY_TIME_MS = 200 -- Query time for the "observableValue" of the "waitingForComparision" function
local CLOUD_SYSTEM = "prod"

-------------------------------------------------------------------------------------
-- Get parameter value from the HTTP request
local function getParameterValue(name)
  local l_value
  for _,v in pairs(m_params) do
    if v:getName() == name then
      l_value = v:getValue()
      break
    end
  end

  return l_value
end

-------------------------------------------------------------------------------------
-- Waiting for a specified comparison value
local function waitingForComparision(observableValue, comparisonValue, comperator)
  local l_watchdogTime = DateTime.getTimestamp() + WATCHDOG_MS
  local l_result = true
  local l_observableValue
  local l_queryTime = 0
  if type(observableValue) == "function" then
    l_observableValue = observableValue()
  else
    l_observableValue = observableValue
  end

  if comperator == "EQUAL" then
    while l_observableValue ~= comparisonValue do
      if DateTime.getTimestamp() > l_watchdogTime then
        print("Error: Watchdog detected")
        l_result = false
        break
      end

      if DateTime.getTimestamp() > l_queryTime and type(observableValue) == "function" then
        l_queryTime = DateTime.getTimestamp() + QUERY_TIME_MS
        l_observableValue = observableValue()
      end
    end
  elseif comperator == "NOT_EQUAL" then
    while l_observableValue == comparisonValue do
      if DateTime.getTimestamp() > l_watchdogTime then
        print("Error: Watchdog detected")
        l_result = false
        break
      end

      if DateTime.getTimestamp() > l_queryTime and type(observableValue) == "function" then
        l_queryTime = DateTime.getTimestamp() + QUERY_TIME_MS
        l_observableValue = observableValue()
      end
    end
  else
    print("Error: Comperator not supported")
    l_result = false
  end

  return l_result
end

-------------------------------------------------------------------------------------
-- Called each time a new test is started
function TestClass:startSuite()

end

-------------------------------------------------------------------------------------
-- Initialization
function TestClass:test01()
  print("============================================================================")
  print("Test-Case 02: Initial setup")
  -- Load parameters
  m_params = UnitTests_LiveConnect.getTestParams()

  m_numRegisteredHttpProfilesExpected = 0
end

-------------------------------------------------------------------------------------
-- Test-case: Pair device [prod]
function TestClass:test02()
  print("============================================================================")
  print("Test-Case 02: Pair device")
  local l_temp
  local l_token = getParameterValue("token")

  if l_token ~= "" then
    -- Go offline
    if CSK_LiveConnect.getConnectionStatus() ~= "Waiting for token validation" then
      print("- Remove old pairing")
      CSK_LiveConnect.removePairing()

      -- Waiting if the device is offline
      l_temp = waitingForComparision(CSK_LiveConnect.getConnectionStatus, "Waiting for token validation", "EQUAL")
      if not l_temp then
        m_lu.assertIsTrue(false, "Can't remove pairing")
      end
    end

    -- Go online using the given pairing token
    print("- Start pairing process")
    CSK_LiveConnect.setCloudSystem(CLOUD_SYSTEM)
    CSK_LiveConnect.setToken(l_token)
    CSK_LiveConnect.startTokenValidation()

    l_temp = waitingForComparision(CSK_LiveConnect.getConnectionStatus, "Online", "EQUAL")
    if not l_temp then
      m_lu.assertIsTrue(false, "Can't pair device (" .. CSK_LiveConnect.getValidateTokenResult() ..")")
    end

    print("- Device paired")
    m_lu.assertIsTrue(true)
  else
    if CSK_LiveConnect.getConnectionStatus() == "Online" then
      print("- Use existing device pairing")

      CSK_LiveConnect.removeAllProfiles()
      print("- Removed all profiles from client")
    else
      m_lu.assertIsTrue(false, "Device is not online (" .. CSK_LiveConnect.getConnectionStatus() ..")")
    end
  end
end

-------------------------------------------------------------------------------------
-- Test-case: Add HTTP profile (LiveConnect HTTP test profile) to a peer device"
function TestClass:test03()
  print("============================================================================")
  print("Test-Case 03: Add HTTP profile (LiveConnect HTTP test profile) to a peer device")
  local l_temp

  local l_profile = m_httpProfile.create()
  m_httpProfile.registerCallbackFunctions(l_profile)


  l_temp = CSK_LiveConnect.addHTTPProfile(PEER_DEVICE.partNumber, PEER_DEVICE.serialNumber, l_profile)
  if not l_temp then
    m_lu.assertIsTrue(false, "Can't add HTTP profile")
  end

  print("- HTTP profile added")
  m_numRegisteredHttpProfilesExpected = m_numRegisteredHttpProfilesExpected + 1
  m_lu.assertIsTrue(true)
end

-------------------------------------------------------------------------------------
-- Test-case: Add MQTT test profile
function TestClass:test04()
  print("============================================================================")
  print("Test-Case 04: Add MQTT profile (LiveConnect MQTT test profile) to a peer device")
  local l_temp

  local l_profile = m_mqttProfile.create()

  l_temp = CSK_LiveConnect.addMQTTProfile(PEER_DEVICE.partNumber, PEER_DEVICE.serialNumber, l_profile)
  if l_temp == nil then
    m_lu.assertIsTrue(false, "Can't add MQTT profile")
  end

  -- Start payload simulation
  m_mqttProfile.startPayloadSimulation(PEER_DEVICE.partNumber, PEER_DEVICE.serialNumber, 5000)
  print("- MQTT payload simulation started")

  print("- MQTT profile added")
  m_lu.assertIsTrue(true)
end

-------------------------------------------------------------------------------------
-- Test-case: Add HTTP profile (LiveConnect HTTP test profile) to the gateway device itself
function TestClass:test05()
  print("============================================================================")
  print("Test-Case 05: Add HTTP profile (LiveConnect HTTP test profile) to the gateway device itself")
  local l_temp
  local l_gatewayPartNumber = CSK_LiveConnect.getGatewayPartNumber()
  local l_gatewaySerialNumber = CSK_LiveConnect.getGatewaySerialNumber()

  local l_profile = m_httpProfile.create()
  m_httpProfile.registerCallbackFunctions(l_profile)

  l_temp = CSK_LiveConnect.addHTTPProfile(l_gatewayPartNumber, l_gatewaySerialNumber, l_profile)
  if not l_temp then
    m_lu.assertIsTrue(false, "Can't add HTTP profile")
  end

  print("- HTTP profile added")
  m_numRegisteredHttpProfilesExpected = m_numRegisteredHttpProfilesExpected + 1
  m_lu.assertIsTrue(true)
end

-------------------------------------------------------------------------------------
-- Test-case: Add MQTT profile (LiveConnect MQTT test profile) to the gateway device itself
function TestClass:test06()
  print("============================================================================")
  print("Test-Case 06: Add MQTT profile (LiveConnect MQTT test profile) to the gateway device itself")
  local l_temp
  local l_gatewayPartNumber = CSK_LiveConnect.getGatewayPartNumber()
  local l_gatewaySerialNumber = CSK_LiveConnect.getGatewaySerialNumber()

  local l_profile = m_mqttProfile.create()

  l_temp = CSK_LiveConnect.addMQTTProfile(l_gatewayPartNumber, l_gatewaySerialNumber, l_profile)
  if l_temp == nil then
    m_lu.assertIsTrue(false, "Can't add MQTT profile")
  end

  -- Start payload simulation
  m_mqttProfile.startPayloadSimulation(l_gatewayPartNumber, l_gatewaySerialNumber, 5000)
  print("- MQTT payload simulation started")

  print("- MQTT profile added")
  m_lu.assertIsTrue(true)
end

-------------------------------------------------------------------------------------
-- Test-case: Check number registered HTTP profiles
function TestClass:test07()
  print("============================================================================")
  print("Test-Case 07: Check number registered profiles")
  local l_devices = CSK_LiveConnect.getRegisteredProfiles()
  local l_numRegisteredProfiles = 0
  for _,device in pairs(l_devices) do
    print("- Device: " .. device:getPartNumber() .. ": ".. tostring(#device:getProfile()) .. " HTTP profiles registered")
    for _,profile in pairs(device:getProfile()) do
      print(" + " .. profile:getName())
    end
    l_numRegisteredProfiles = l_numRegisteredProfiles + #device:getProfile()
  end

  if l_numRegisteredProfiles == (m_numRegisteredHttpProfilesExpected + 2) then
    m_lu.assertIsTrue(true)
  else
    m_lu.assertIsTrue(false, string.format("Number of registered profiles (%s) doesn't match with the expected number (%s)", l_numRegisteredProfiles, m_numRegisteredHttpProfilesExpected))
  end
end