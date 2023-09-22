---@diagnostic disable: param-type-mismatch, undefined-global, redundant-parameter

--***********************************************************************************
-- Inside of this script, you will find the necessary functions,
-- variables and events to communicate with the LiveConnect_Model
--***********************************************************************************

--**************************************************************************
--************************ Start Global Scope ******************************
--**************************************************************************

-------------------------------------------------------------------------------------
-- Variables
local m_mqttCapabilitiesObject = require("Communication.LiveConnect.profileImpl.MQTTCapabilitiesObject")
local m_mqttIdentificationObject = require("Communication.LiveConnect.profileImpl.MQTTIdentificationObject")
local m_mqttAsyncApiObject = require("Communication.LiveConnect.profileImpl.MQTTAsyncApiObject")
local m_httpCapabilitiesObject = require("Communication.LiveConnect.profileImpl.HTTPCapabilitiesObject")
local m_httpApplicationObject = require("Communication.LiveConnect.profileImpl.HTTPApplicationObject")
local m_devices = {}
local m_clearValidateTokenResultTimer = Timer.create()
local m_validateTokenResult = ""

-------------------------------------------------------------------------------------
-- Constant values
local NAME_OF_MODULE = 'CSK_LiveConnect'

-- Timer to update UI via events after page was loaded
local m_tmrLiveConnect = Timer.create()
m_tmrLiveConnect:setExpirationTime(300)
m_tmrLiveConnect:setPeriodic(false)

-- Reference to global handle
local liveConnect_Model

-- **********************************************************************************
-- UI Events
-- **********************************************************************************

Script.serveEvent("CSK_LiveConnect.OnClientInitialized", "LiveConnect_OnClientInitialized")
Script.serveEvent('CSK_LiveConnect.UI.OnNewStatusSystemClockConfigured', 'LiveConnect_OnNewStatusSystemClockConfigured')
Script.serveEvent('CSK_LiveConnect.UI.OnNewStatusSystemClock', 'LiveConnect_OnNewStatusSystemClock')
Script.serveEvent('CSK_LiveConnect.OnNewStatusConnectionStatus', 'LiveConnect_OnNewStatusConnectionStatus')
Script.serveEvent('CSK_LiveConnect.OnNewStatusDeviceURL', 'LiveConnect_OnNewStatusDeviceURL')
Script.serveEvent('CSK_LiveConnect.UI.OnNewStatusCurrentView', 'LiveConnect_OnNewStatusCurrentView')

Script.serveEvent("CSK_LiveConnect.OnNewStatusLoadParameterOnReboot", "LiveConnect_OnNewStatusLoadParameterOnReboot")
Script.serveEvent("CSK_LiveConnect.OnPersistentDataModuleAvailable", "LiveConnect_OnPersistentDataModuleAvailable")
Script.serveEvent("CSK_LiveConnect.OnNewParameterName", "LiveConnect_OnNewParameterName")
Script.serveEvent("CSK_LiveConnect.OnDataLoadedOnReboot", "LiveConnect_OnDataLoadedOnReboot")

Script.serveEvent('CSK_LiveConnect.OnUserLevelOperatorActive', 'LiveConnect_OnUserLevelOperatorActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelMaintenanceActive', 'LiveConnect_OnUserLevelMaintenanceActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelServiceActive', 'LiveConnect_OnUserLevelServiceActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelAdminActive', 'LiveConnect_OnUserLevelAdminActive')

Script.serveEvent('CSK_LiveConnect.OnNewProfileAdded', 'LiveConnect_OnNewProfileAdded')

Script.serveEvent("CSK_LiveConnect.OnNewMQTTKeepAliveInterval", 'LiveConnect_OnNewMQTTKeepAliveInterval')
Script.serveEvent("CSK_LiveConnect.OnNewMQTTConnectTimeout", 'LiveConnect_OnNewMQTTConnectTimeout')
Script.serveEvent("CSK_LiveConnect.OnNewMQTTMessageInterval", 'LiveConnect_OnNewMQTTMessageInterval')
Script.serveEvent("CSK_LiveConnect.OnNewMQTTQueueSize", 'LiveConnect_OnNewMQTTQueueSize')
Script.serveEvent("CSK_LiveConnect.OnNewProcessInterval", 'LiveConnect_OnNewProcessInterval')
Script.serveEvent("CSK_LiveConnect.OnNewTokenTimeout", 'LiveConnect_OnNewTokenTimeout')
Script.serveEvent("CSK_LiveConnect.OnNewDeviceDiscoveryTimeout", 'LiveConnect_OnNewDeviceDiscoveryTimeout')
Script.serveEvent("CSK_LiveConnect.OnNewGatewayPartNumber", 'LiveConnect_OnNewGatewayPartNumber')
Script.serveEvent("CSK_LiveConnect.OnNewGatewaySerialNumber", 'LiveConnect_OnNewGatewaySerialNumber')
Script.serveEvent("CSK_LiveConnect.OnNewCloudSystem", 'LiveConnect_OnNewCloudSystem')
Script.serveEvent("CSK_LiveConnect.OnNewValidateTokenResult", 'LiveConnect_OnNewValidateTokenResult')

-- **********************************************************************************
-- Start CSK Base Functions
-- **********************************************************************************

-------------------------------------------------------------------------------------
-- Functions to forward logged in user roles via CSK_UserManagement module (if available)
-- ***********************************************

--- Function to react on status change of Operator user level
---@param status boolean Status if Operator level is active
local function handleOnUserLevelOperatorActive(status)
  Script.notifyEvent("LiveConnect_OnUserLevelOperatorActive", status)
end

--- Function to react on status change of Maintenance user level
---@param status boolean Status if Maintenance level is active
local function handleOnUserLevelMaintenanceActive(status)
  Script.notifyEvent("LiveConnect_OnUserLevelMaintenanceActive", status)
end

--- Function to react on status change of Service user level
---@param status boolean Status if Service level is active
local function handleOnUserLevelServiceActive(status)
  Script.notifyEvent("LiveConnect_OnUserLevelServiceActive", status)
end

--- Function to react on status change of Admin user level
---@param status boolean Status if Admin level is active
local function handleOnUserLevelAdminActive(status)
  Script.notifyEvent("LiveConnect_OnUserLevelAdminActive", status)
end

-- Function to get access to the liveConnect_Model object
---@param handle handle Handle of encoder_Model object
local function setLiveConnect_Model_Handle(handle)
  liveConnect_Model = handle
  if liveConnect_Model.userManagementModuleAvailable then
    -- Register on events of CSK_UserManagement module if available
    Script.register('CSK_UserManagement.OnUserLevelOperatorActive', handleOnUserLevelOperatorActive)
    Script.register('CSK_UserManagement.OnUserLevelMaintenanceActive', handleOnUserLevelMaintenanceActive)
    Script.register('CSK_UserManagement.OnUserLevelServiceActive', handleOnUserLevelServiceActive)
    Script.register('CSK_UserManagement.OnUserLevelAdminActive', handleOnUserLevelAdminActive)
  end
  Script.releaseObject(handle)
end

-------------------------------------------------------------------------------------
-- Function to update user levels
local function updateUserLevel()
  if liveConnect_Model.userManagementModuleAvailable then
    -- Trigger CSK_UserManagement module to provide events regarding user role
    CSK_UserManagement.pageCalled()
  else
    -- If CSK_UserManagement is not active, show everything
    Script.notifyEvent("LiveConnect_OnUserLevelAdminActive", true)
    Script.notifyEvent("LiveConnect_OnUserLevelMaintenanceActive", true)
    Script.notifyEvent("LiveConnect_OnUserLevelServiceActive", true)
    Script.notifyEvent("LiveConnect_OnUserLevelOperatorActive", true)
  end
end

-------------------------------------------------------------------------------------
-- Function to send all relevant values to UI on resume
local function handleOnExpiredTmrLiveConnect()
  updateUserLevel()

  Script.notifyEvent("LiveConnect_OnNewStatusSystemClockConfigured", CSK_LiveConnect.UI.isSystemClockConfigured())
  Script.notifyEvent("LiveConnect_OnNewStatusSystemClock", CSK_LiveConnect.UI.getSystemClockStatus())
  Script.notifyEvent("LiveConnect_OnNewStatusConnectionStatus", CSK_LiveConnect.getConnectionStatus())
  Script.notifyEvent("LiveConnect_OnNewStatusDeviceURL", CSK_LiveConnect.getDeviceURL())
  Script.notifyEvent("LiveConnect_OnNewStatusCurrentView", CSK_LiveConnect.UI.getCurrentView())

  Script.notifyEvent("LiveConnect_OnNewStatusLoadParameterOnReboot", liveConnect_Model.parameterLoadOnReboot)
  Script.notifyEvent("LiveConnect_OnPersistentDataModuleAvailable", liveConnect_Model.persistentModuleAvailable)
  Script.notifyEvent("LiveConnect_OnNewParameterName", liveConnect_Model.parametersName)

  Script.notifyEvent("LiveConnect_OnNewMQTTConnectTimeout", tostring(liveConnect_Model.parameters.mqttConnectTimeoutMs))
  Script.notifyEvent("LiveConnect_OnNewMQTTKeepAliveInterval", tostring(liveConnect_Model.parameters.mqttKeepAliveIntervalMs))
  Script.notifyEvent("LiveConnect_OnNewMQTTMessageInterval", tostring(liveConnect_Model.parameters.mqttMessageForwardingIntervalMs))
  Script.notifyEvent("LiveConnect_OnNewMQTTQueueSize", tostring(liveConnect_Model.parameters.mqttMessageQueueMaxLength))

  Script.notifyEvent("LiveConnect_OnNewProcessInterval", tostring(liveConnect_Model.parameters.processIntervalMs))
  Script.notifyEvent("LiveConnect_OnNewTokenTimeout", tostring(liveConnect_Model.parameters.tokenTimeoutMs))
  Script.notifyEvent("LiveConnect_OnNewDeviceDiscoveryTimeout", tostring(liveConnect_Model.parameters.discoveryTimeoutMs))
  Script.notifyEvent("LiveConnect_OnNewGatewayPartNumber", liveConnect_Model.parameters.partNumber)
  Script.notifyEvent("LiveConnect_OnNewGatewaySerialNumber", liveConnect_Model.parameters.serialNumber)
  Script.notifyEvent("LiveConnect_OnNewCloudSystem", liveConnect_Model.parameters.cloudSystem)
end
Timer.register(m_tmrLiveConnect, "OnExpired", handleOnExpiredTmrLiveConnect)

-- **********************************************************************************
-- Start of LiveConnect Client functions
-- **********************************************************************************

-------------------------------------------------------------------------------------
-- Get array length
---@param data table
---@return number 
local function getArrayLength(data)
  local l_len = 0
  for _,_ in pairs(data) do
    l_len = l_len + 1
  end
  return l_len
end

-------------------------------------------------------------------------------------
-- Generate a random UUID
---@return string
local function createUUID()
  local l_template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  local l_uuid =  string.gsub(l_template, '[xy]', function (c)
    local l_val = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', l_val)
  end)

  return l_uuid
end

-------------------------------------------------------------------------------------
-- Clear token when the validation timer is exceeded
local function clearValidateTokenResult()
  m_validateTokenResult = ""
  Script.notifyEvent("LiveConnect_OnNewValidateTokenResult", m_validateTokenResult)
end

-------------------------------------------------------------------------------------
-- Publish token result
---@param tokenResult string
local function publishValidateTokenResult(tokenResult)
  m_validateTokenResult = tokenResult
  Script.notifyEvent("LiveConnect_OnNewValidateTokenResult", tokenResult)

  m_clearValidateTokenResultTimer:setExpirationTime(15000)
  m_clearValidateTokenResultTimer:register("OnExpired", clearValidateTokenResult)
  m_clearValidateTokenResultTimer:start()
end

-------------------------------------------------------------------------------------
-- Start token validation
local function startTokenValidation()
  clearValidateTokenResult()

  local l_token = liveConnect_Model.iccClient.softApprovalToken
  _G.logger:info(NAME_OF_MODULE .. ": Validate Token (" .. l_token .. ")")
  l_token = string.gsub(l_token, "^%s*(.-)%s*$", "%1") -- trim
  if nil ~= l_token and l_token ~= "" then
    local l_success, l_statusMessage = liveConnect_Model.iccClient:validateToken(l_token)
    if (l_success) then
      liveConnect_Model.iccClient.softApprovalToken = ""
      publishValidateTokenResult("Registration successful")
    else
      publishValidateTokenResult("Token validation error: " .. l_statusMessage)
    end
  else
    publishValidateTokenResult("Token validation error: Empty token")
  end
  CSK_LiveConnect.pageCalled()
end
Script.serveFunction("CSK_LiveConnect.startTokenValidation", startTokenValidation)

-------------------------------------------------------------------------------------
-- Remove pairing between the phsical device and the digital twin in the SICK AssetHub
local function removePairing()
  _G.logger:info(NAME_OF_MODULE .. ": Remove pairing")
  liveConnect_Model.iccClient:removePairing()

  clearValidateTokenResult()
end
Script.serveFunction("CSK_LiveConnect.removePairing", removePairing)

-------------------------------------------------------------------------------------

local function getDeviceURL()
  local l_cloudSystem = liveConnect_Model.parameters.cloudSystem
  local l_deviceUUID = liveConnect_Model.iccClient.deviceUuid
  if l_deviceUUID == nil then
    return ""
  end

  if l_cloudSystem == "prod" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return string.format("https://assethub.cloud.sick.com/liveconnect/%s", l_deviceUUID)
  elseif l_cloudSystem == "int" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return string.format("https://assethub.int.sickag.cloud/liveconnect/%s", l_deviceUUID)
  elseif l_cloudSystem == "dev" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return string.format("https://assethub.dev.sickag.cloud/liveconnect/%s", l_deviceUUID)
  else
    return ""
  end
end
Script.serveFunction("CSK_LiveConnect.getDeviceURL", getDeviceURL)

-------------------------------------------------------------------------------------

local function getCurrentView()
  local ret = liveConnect_Model.iccClient.deviceUuid
  if ret == nil then
    return "0" -- Show paring code and button 
  end
  return "1" -- Show device url and unpair buttons
end
Script.serveFunction("CSK_LiveConnect.UI.getCurrentView", getCurrentView)

-------------------------------------------------------------------------------------

local function setToken(token)
  _G.logger:info(NAME_OF_MODULE .. ": Set soft approval token (" .. token ..")")
  liveConnect_Model.iccClient.softApprovalToken = token
end
Script.serveFunction("CSK_LiveConnect.setToken", setToken)

-------------------------------------------------------------------------------------

local function getConnectionStatus()
  if not liveConnect_Model.iccClient:isEnabled() then
    return "Offline"
  else
    local l_currentState = liveConnect_Model.iccClient:getConnectionState()
    if l_currentState == 'CONNECTED' then
      return "Online"
    elseif l_currentState == 'EXECUTING_COMMAND' then
      return "Execute command"
    elseif l_currentState == 'DISCOVERY_RESPONSE_RECEIVED' then
      return "Discover devices"
    elseif l_currentState == 'CHECK_PAIRING' then
      return "Waiting for token validation"
    else
      return "Offline"
    end
  end
end
Script.serveFunction("CSK_LiveConnect.getConnectionStatus", getConnectionStatus)

-------------------------------------------------------------------------------------
-- Create / get a device and assign a UUID
---@param partNumber string
---@param serialNumber string
---@return table
---@return bool
local function getDevice(partNumber, serialNumber)
  local l_isNewDevice = true
  local l_index = partNumber .. serialNumber
  -- Check if the device is a peer device
  local l_isPeerDevice = not ((partNumber == liveConnect_Model.parameters.partNumber) and (serialNumber == liveConnect_Model.parameters.serialNumber))
  local l_deviceUUID = createUUID()
  local l_deviceURL;
  if l_isPeerDevice then
    l_deviceURL = liveConnect_Model.iccClient.standardInterfaceServer .. "/gateway/" .. l_deviceUUID
  else
    l_deviceURL = liveConnect_Model.iccClient.standardInterfaceServer
  end

  if getArrayLength(m_devices) > 0 then
    for index,_ in pairs(m_devices) do
      if index == l_index then
        l_isNewDevice = false
        break
      end
    end
  end

  if l_isNewDevice then
    m_devices[l_index] = {
      uuid = l_deviceUUID,
      httpCapabilities = nil,
      mqttCapabilities = nil,
      mqttIdentification = nil,
      mqttAsyncApi = nil,
      isPeerDevice = l_isPeerDevice,
      partNumber = partNumber,
      serialNumber = serialNumber,
      url = l_deviceURL
    }
  end

  return m_devices[l_index], l_isNewDevice
end

-------------------------------------------------------------------------------------
-- Add / update http profiles of a peer device
-- Create a new peer device if it doesn't already exist
---@param device table
---@param isNewDevice bool
---@param applicationProfile CSK_LiveConnect.HTTPProfile
local function handlePeerDevice(device, isNewDevice, applicationProfile)
  if isNewDevice then
    -- Add capabilities profile
    device.httpCapabilities = m_httpCapabilitiesObject.create(device.url)
    for serviceLocation, crownName in pairs(device.httpCapabilities:getEndpoints()) do
      liveConnect_Model.iccClient:addEndpoint(serviceLocation, crownName)
    end
    device.httpCapabilities:addProfile(device.httpCapabilities.profile)

    -- Add additional application profiles to capabilities
    if applicationProfile ~= nil then
      device.httpCapabilities:addProfile(applicationProfile)
    end

    -- Add new peer device 
    liveConnect_Model.iccClient:addPeerDevice(device.partNumber, device.serialNumber, device.url)
  else
    -- Add additional application profiles to capabilities
    if applicationProfile ~= nil then
      device.httpCapabilities:addProfile(applicationProfile)
    end

    -- Start profile update process
    liveConnect_Model.iccClient:reloadProfiles()
  end
end

-------------------------------------------------------------------------------------

local function addMQTTProfile(partNumber, serialNumber, mqttProfile)
  if liveConnect_Model.iccClient ~= nil then
    _G.logger:info(NAME_OF_MODULE .. ": Register MQTT profile (" .. mqttProfile:getName() .. ")")

    -- Get UUID of the device 
    local l_device, l_isNewDevice = getDevice(partNumber, serialNumber)

    -- Create peer devie if it doesn't already exist
    handlePeerDevice(l_device, l_isNewDevice, nil)

    -- Add capabilities profile
    if l_device.mqttCapabilities == nil then
      _G.logger:fine(string.format("%s: Add MQTT capabilities profile to device (PN: %s | SN: %s)", NAME_OF_MODULE, l_device.partNumber, l_device.serialNumber))
      l_device.mqttCapabilities = m_mqttCapabilitiesObject.create(liveConnect_Model.iccClient.mqttTopicBaseCapabilities)
      l_device.mqttCapabilities:addProfile(l_device.mqttCapabilities.profile)

      -- Publish async api profile payload
      local l_profileId = CSK_LiveConnect.MQTTProfile.getUUID(l_device.mqttCapabilities.profile)
      local l_asyncApiTopic = string.format('%s/%s/%s', liveConnect_Model.iccClient.mqttTopicAsyncApi, l_profileId, l_device.uuid)
      local l_asyncApiPayload = CSK_LiveConnect.MQTTProfile.getAsyncAPISpecification(l_device.mqttCapabilities.profile)
      liveConnect_Model.iccClient:addMQTTTopic(l_asyncApiTopic, l_asyncApiPayload, "QOS1")
    end

    -- Add identification profile
    if l_device.mqttIdentification == nil then
      _G.logger:fine(string.format("%s: Add MQTT identification profile to device (PN: %s | SN: %s)", NAME_OF_MODULE, l_device.partNumber, l_device.serialNumber))
      l_device.mqttIdentification = m_mqttIdentificationObject.create(
        liveConnect_Model.iccClient.mqttTopicBaseIdentification,
        liveConnect_Model.iccClient.iccClientName,
        l_device.partNumber,
        l_device.serialNumber)

      l_device.mqttCapabilities:addProfile(l_device.mqttIdentification.profile)

      -- Publish identification profile payload
      local l_deviceIdentificationTopic = string.format('%s/%s', liveConnect_Model.iccClient.mqttTopicBaseIdentification, l_device.uuid)
      local l_deviceIdentificationPayload = l_device.mqttIdentification:getPayload()
      liveConnect_Model.iccClient:addMQTTTopic(l_deviceIdentificationTopic, l_deviceIdentificationPayload, "QOS1")

      -- Publish async api profile payload
      local l_profileId = CSK_LiveConnect.MQTTProfile.getUUID(l_device.mqttIdentification.profile)
      local l_asyncApiTopic = string.format('%s/%s/%s', liveConnect_Model.iccClient.mqttTopicAsyncApi, l_profileId, l_device.uuid)
      local l_asyncApiPayload = CSK_LiveConnect.MQTTProfile.getAsyncAPISpecification(l_device.mqttIdentification.profile)
      liveConnect_Model.iccClient:addMQTTTopic(l_asyncApiTopic, l_asyncApiPayload, "QOS1")
    end

    -- Add async api profile
    if l_device.mqttAsyncApi == nil then
      _G.logger:fine(string.format("%s: Add MQTT async api profile to device (PN: %s | SN: %s)", NAME_OF_MODULE, l_device.partNumber, l_device.serialNumber))
      l_device.mqttAsyncApi = m_mqttAsyncApiObject.create(
        liveConnect_Model.iccClient.mqttTopicAsyncApi
      )

      l_device.mqttCapabilities:addProfile(l_device.mqttAsyncApi.profile)

      -- Publish async api profile payload
      local l_profileId = CSK_LiveConnect.MQTTProfile.getUUID(l_device.mqttAsyncApi.profile)
      local l_asyncApiTopic = string.format('%s/%s/%s', liveConnect_Model.iccClient.mqttTopicAsyncApi, l_profileId, l_device.uuid)
      local l_asyncApiPayload = CSK_LiveConnect.MQTTProfile.getAsyncAPISpecification(l_device.mqttAsyncApi.profile)
      liveConnect_Model.iccClient:addMQTTTopic(l_asyncApiTopic, l_asyncApiPayload, "QOS1")
    end

    -- Add application profile to the capabilities
    l_device.mqttCapabilities:addProfile(mqttProfile)

    -- Publish async api profile payload
    local l_profileId = CSK_LiveConnect.MQTTProfile.getUUID(mqttProfile)
    local l_asyncApiTopic = string.format('%s/%s/%s', liveConnect_Model.iccClient.mqttTopicAsyncApi, l_profileId, l_device.uuid)
    local l_asyncApiPayload = CSK_LiveConnect.MQTTProfile.getAsyncAPISpecification(mqttProfile)
    liveConnect_Model.iccClient:addMQTTTopic(l_asyncApiTopic, l_asyncApiPayload, "QOS1")

    -- Publish and update of the capabilities profile payload
    local l_capabilitiesTopic = string.format('%s/%s', liveConnect_Model.iccClient.mqttTopicBaseCapabilities, l_device.uuid)
    local l_capabilitiesPayload = l_device.mqttCapabilities:getPayload()
    liveConnect_Model.iccClient:addMQTTTopic(l_capabilitiesTopic, l_capabilitiesPayload, "QOS1")

    Script.notifyEvent("LiveConnect_OnNewProfileAdded", mqttProfile:getName(), "asyncAPI")
    return l_device.uuid
  else
    _G.logger:warning(NAME_OF_MODULE .. ": Can't add MQTT profile, because the LiveConnect client is not yet initialized. The client needs 100ms to initialize itself.")

    ---@diagnostic disable-next-line: return-type-mismatch
    return nil
  end
end
Script.serveFunction("CSK_LiveConnect.addMQTTProfile", addMQTTProfile)

-------------------------------------------------------------------------------------

local function addHTTPProfile(partNumber, serialNumber, httpProfile)
  if liveConnect_Model.iccClient ~= nil then
    _G.logger:info(NAME_OF_MODULE .. ": Register HTTP profile (" .. httpProfile:getName() .. ")")
    local l_device, l_isNewDevice = getDevice(partNumber, serialNumber)

    if l_device.isPeerDevice then
      -- Add application profile
      local l_applicationProfile = m_httpApplicationObject.create(l_device.url, httpProfile)
      for serviceLocation, endpoint in pairs(l_applicationProfile:getEndpoints()) do
        liveConnect_Model.iccClient:addEndpoint(serviceLocation, endpoint)
      end

      liveConnect_Model.iccClient:addHTTPProfilePeerDevice(l_applicationProfile.profile, partNumber, serialNumber)

      handlePeerDevice(l_device, l_isNewDevice, httpProfile)
    else
      -- Add application profile
      local l_applicationProfile = m_httpApplicationObject.create(l_device.url, httpProfile)
      for serviceLocation, endpoint in pairs(l_applicationProfile:getEndpoints()) do
        liveConnect_Model.iccClient:addEndpoint(serviceLocation, endpoint)
      end
      liveConnect_Model.iccClient:addHTTPProfileGatewayDevice(l_applicationProfile.profile)

      -- Start profile update process
      liveConnect_Model.iccClient:reloadProfiles()
    end

    -- Check if profile was successfully added
    Script.notifyEvent("LiveConnect_OnNewProfileAdded", httpProfile:getName(), "openAPI")
    return true
  else
    _G.logger:warning(NAME_OF_MODULE .. ": Can't add HTTP profile, because the LiveConnect client is not yet initialized. The client needs 100ms to initialize itself.")
      return false
  end
end
Script.serveFunction("CSK_LiveConnect.addHTTPProfile", addHTTPProfile)

-------------------------------------------------------------------------------------

local function publishMQTTData(topic, partNumber, serialNumber, payload)
  -- Get meta information about the device
  local l_device = m_devices[partNumber .. serialNumber]

  if l_device ~= nil then
    -- Add uuid
    local l_topicWithUUID = string.format('%s/%s', topic, l_device.uuid)

    -- Add data to the mqtt message queue
    _G.logger:fine(string.format("%s: Publish MQTT data (%s): %s", NAME_OF_MODULE, l_topicWithUUID, payload))
    liveConnect_Model.iccClient:addMQTTTopic(l_topicWithUUID, payload, "QOS1")
  end
end
Script.serveFunction("CSK_LiveConnect.publishMQTTData", publishMQTTData)

-------------------------------------------------------------------------------------

local function publishMQTTDataByID(topic, deviceUUID, payload)
  local l_device = nil
  for _, device in pairs(m_devices) do
    if (device.uuid == deviceUUID) then
      l_device = device
      break
    end
  end

  if l_device ~= nil then
    publishMQTTData(topic, l_device.partNumber, l_device.serialNumber, payload)
  else
    _G.logger:warning(string.format("%s: Can't publish MQTT data. Device UUID (%s) can't be assigned", NAME_OF_MODULE, deviceUUID))
  end
end
Script.serveFunction("CSK_LiveConnect.publishMQTTDataByID", publishMQTTDataByID)

-------------------------------------------------------------------------------------

local function isSystemClockConfigured()
  -- Check if time is set correctly
  -- Check if day 2023-08-11T00:00:00Z pasted
  local l_ret = DateTime.getUnixTime() >= 1691704800

  return l_ret
end
Script.serveFunction("CSK_LiveConnect.UI.isSystemClockConfigured", isSystemClockConfigured)

-------------------------------------------------------------------------------------

local function getSystemClockStatus()
  local l_day, l_month, l_year, l_hour, l_minute, l_second, _ = DateTime.getDateTimeValuesUTC()
  local l_timeString = string.format("%04d-%02d-%02d %02d:%02d:%02d UTC",
    l_year, l_month, l_day, l_hour, l_minute, l_second)

  local l_ret = string.format("%s (%s)",
    (isSystemClockConfigured() and "Configured" or "Not configured"),
    l_timeString
  )

  ---@diagnostic disable-next-line: return-type-mismatch
  return l_ret
end
Script.serveFunction("CSK_LiveConnect.UI.getSystemClockStatus", getSystemClockStatus)

-------------------------------------------------------------------------------------

local function removePeerDevice(partNumber, serialNumber)
  _G.logger:info(string.format("%s: Remove peer device (PN: %s / SN: %s)",NAME_OF_MODULE, partNumber, serialNumber))
  liveConnect_Model.iccClient:removePeerDevice(partNumber, serialNumber)
end
Script.serveFunction("CSK_LiveConnect.removePeerDevice", removePeerDevice)

-------------------------------------------------------------------------------------

local function setMQTTMessageQueueSize(queueSize)
  _G.logger:info(string.format("%s: Set MQTT message queue size (%s)", NAME_OF_MODULE, queueSize))
  liveConnect_Model.parameters.mqttMessageQueueMaxLength = tonumber(queueSize)
end
Script.serveFunction("CSK_LiveConnect.setMQTTMessageQueueSize", setMQTTMessageQueueSize)

-------------------------------------------------------------------------------------

local function setMQTTKeepAliveInterval(keepAliveInterval)
  _G.logger:info(string.format("%s: Set MQTT keep alive interval (%sms)", NAME_OF_MODULE, keepAliveInterval))
  liveConnect_Model.parameters.mqttKeepAliveIntervalMs = tonumber(keepAliveInterval)
end
Script.serveFunction("CSK_LiveConnect.setMQTTKeepAliveInterval", setMQTTKeepAliveInterval)

-------------------------------------------------------------------------------------

local function setMQTTConnectTimeout(connectTimeout)
  _G.logger:info(string.format("%s: Set MQTT connect timeout (%sms)", NAME_OF_MODULE, connectTimeout))
  liveConnect_Model.parameters.mqttConnectTimeoutMs = tonumber(connectTimeout)
end
Script.serveFunction("CSK_LiveConnect.setMQTTConnectTimeout", setMQTTConnectTimeout)

-------------------------------------------------------------------------------------

local function setMQTTMessageInterval(messageInterval)
  _G.logger:info(string.format("%s: Set MQTT message forwarding interval (%sms)", NAME_OF_MODULE, messageInterval))
  liveConnect_Model.parameters.mqttMessageForwardingIntervalMs = tonumber(messageInterval)
end
Script.serveFunction("CSK_LiveConnect.setMQTTMessageInterval", setMQTTMessageInterval)

-------------------------------------------------------------------------------------

local function setProcessInterval(interval)
  _G.logger:info(string.format("%s: Set process interval (%sms)", NAME_OF_MODULE, interval))
  liveConnect_Model.parameters.processIntervalMs = tonumber(interval)
end
Script.serveFunction('CSK_LiveConnect.setProcessInterval', setProcessInterval)

-------------------------------------------------------------------------------------

local function setTokenTimeout(timeout)
  _G.logger:info(string.format("%s: Set token timeout (%sms)", NAME_OF_MODULE, timeout))
  liveConnect_Model.parameters.tokenTimeoutMs = tonumber(timeout)
end
Script.serveFunction('CSK_LiveConnect.setTokenTimeout', setTokenTimeout)

-------------------------------------------------------------------------------------

local function setDeviceDiscoveryTimeout(timeout)
  _G.logger:info(string.format("%s: Set device discovery timeout (%sms)", NAME_OF_MODULE, timeout))
  liveConnect_Model.parameters.discoveryTimeoutMs = tonumber(timeout)
end
Script.serveFunction('CSK_LiveConnect.setDeviceDiscoveryTimeout', setDeviceDiscoveryTimeout)

-------------------------------------------------------------------------------------

local function setGatewayPartNumber(partNumber)
  _G.logger:info(string.format("%s: Set part number of the gateway device (%s)", NAME_OF_MODULE, partNumber))
  liveConnect_Model.parameters.partNumber = partNumber
end
Script.serveFunction('CSK_LiveConnect.setGatewayPartNumber', setGatewayPartNumber)

-------------------------------------------------------------------------------------

local function getGatewayPartNumber()
  return liveConnect_Model.parameters.partNumber
end
Script.serveFunction('CSK_LiveConnect.getGatewayPartNumber', getGatewayPartNumber)

-------------------------------------------------------------------------------------

local function setGatewaySerialNumber(serialNumber)
  _G.logger:info(string.format("%s: Set serial number of the gateway device (%s)", NAME_OF_MODULE, serialNumber))
  liveConnect_Model.parameters.serialNumber = serialNumber
end
Script.serveFunction('CSK_LiveConnect.setGatewaySerialNumber', setGatewaySerialNumber)

-------------------------------------------------------------------------------------

local function getGatewaySerialNumber()
  return liveConnect_Model.parameters.serialNumber
end
Script.serveFunction('CSK_LiveConnect.getGatewaySerialNumber', getGatewaySerialNumber)

-------------------------------------------------------------------------------------

local function setCloudSystem(cloudSystem)
  _G.logger:info(string.format("%s: Set cloud system (%s)", NAME_OF_MODULE, cloudSystem))
  liveConnect_Model.parameters.cloudSystem = cloudSystem
end
Script.serveFunction('CSK_LiveConnect.setCloudSystem', setCloudSystem)

-------------------------------------------------------------------------------------

local function getRegisteredProfiles()
  local l_devices = {}
  if liveConnect_Model.iccClient ~= nil then
    -- Add gateway device
    local l_gatewayDevice = CSK_LiveConnect.Device.create()
    l_gatewayDevice:setDeviceType("GATEWAY_DEVICE")
    l_gatewayDevice:setPartNumber(liveConnect_Model.parameters.partNumber)
    l_gatewayDevice:setSerialNumber(liveConnect_Model.parameters.serialNumber)
    l_gatewayDevice:setDeviceUUID(liveConnect_Model.iccClient.deviceUuid)
    l_gatewayDevice:setProfile(liveConnect_Model.iccClient.httpProfilesGatewayDevice)
    table.insert(l_devices, l_gatewayDevice)

    -- Add peer devices
    if liveConnect_Model.iccClient.peerDevices ~= nil then
      if liveConnect_Model.iccClient.peerDevices ~= {} then
        for index,peerDevice in pairs(liveConnect_Model.iccClient.peerDevices) do
          local l_peerDevice = CSK_LiveConnect.Device.create()
          l_peerDevice:setDeviceType("PEER_DEVICE")
          l_peerDevice:setPartNumber(peerDevice.partNumber)
          l_peerDevice:setSerialNumber(peerDevice.serialNumber)
          l_peerDevice:setDeviceUUID(peerDevice.deviceUuid)

          local l_peerProfiles = {}
          for _, profile in pairs(liveConnect_Model.iccClient.httpProfilesPeerDevice[index]) do
            table.insert(l_peerProfiles, profile)
          end
          l_peerDevice:setProfile(l_peerProfiles)

          table.insert(l_devices, l_peerDevice)
        end
      end
    end
  else
    _G.logger:warning(NAME_OF_MODULE .. ": LiveConnect client is not yet initialized. The client needs 100ms to initialize itself.")
  end

  return l_devices
end
Script.serveFunction('CSK_LiveConnect.getRegisteredProfiles', getRegisteredProfiles)

-------------------------------------------------------------------------------------

local function getValidateTokenResult()
  return m_validateTokenResult
end
Script.serveFunction('CSK_LiveConnect.getValidateTokenResult', getValidateTokenResult)

-------------------------------------------------------------------------------------

local function removeAllProfiles()
  _G.logger:info(NAME_OF_MODULE .. ": Removing all profiles and connected devices")
  m_devices = {}
  liveConnect_Model.iccClient:removeAllProfiles()
end
Script.serveFunction("CSK_LiveConnect.removeAllProfiles", removeAllProfiles)

-------------------------------------------------------------------------------------

local function pageCalled()
  updateUserLevel() -- try to hide user specific content asap
  m_tmrLiveConnect:start()
  return ''
end
Script.serveFunction("CSK_LiveConnect.pageCalled", pageCalled)

-- *****************************************************************
-- Following function can be adapted for CSK_PersistentData module usage
-- *****************************************************************

-------------------------------------------------------------------------------------

local function setParameterName(name)
  _G.logger:info(NAME_OF_MODULE .. ": Set parameter name: " .. tostring(name))
  liveConnect_Model.parametersName = tostring(name)
end
Script.serveFunction("CSK_LiveConnect.setParameterName", setParameterName)

local function sendParameters()
  if liveConnect_Model.persistentModuleAvailable then
    CSK_PersistentData.addParameter(liveConnect_Model.helperFuncs.convertTable2Container(liveConnect_Model.parameters), liveConnect_Model.parametersName)
    CSK_PersistentData.setModuleParameterName(NAME_OF_MODULE, liveConnect_Model.parametersName, liveConnect_Model.parameterLoadOnReboot)
    _G.logger:info(NAME_OF_MODULE .. ": Send LiveConnect parameters with name '" .. liveConnect_Model.parametersName .. "' to CSK_PersistentData module.")
    CSK_PersistentData.saveData()

    -- Reinit LiveConnect client to ensure that the parameters are accepted
    liveConnect_Model.iccClient:reinit()
  else
    _G.logger:warning(NAME_OF_MODULE .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_LiveConnect.sendParameters", sendParameters)

local function loadParameters()
  if liveConnect_Model.persistentModuleAvailable then
    local data = CSK_PersistentData.getParameter(liveConnect_Model.parametersName)
    if data then
      _G.logger:info(NAME_OF_MODULE .. ": Loaded parameters from CSK_PersistentData module.")
      liveConnect_Model.parameters = liveConnect_Model.helperFuncs.convertContainer2Table(data)

      -- Reinit LiveConnect client to ensure that the parameters are accepted
      liveConnect_Model.iccClient:reinit()

      CSK_LiveConnect.pageCalled()
    else
      _G.logger:warning(NAME_OF_MODULE .. ": Loading parameters from CSK_PersistentData module did not work.")
    end
  else
    _G.logger:warning(NAME_OF_MODULE .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_LiveConnect.loadParameters", loadParameters)

local function setLoadOnReboot(status)
  liveConnect_Model.parameterLoadOnReboot = status
  _G.logger:info(NAME_OF_MODULE .. ": Set new status to load setting on reboot: " .. tostring(status))
end
Script.serveFunction("CSK_LiveConnect.setLoadOnReboot", setLoadOnReboot)

--- Function to react on initial load of persistent parameters
local function handleOnInitialDataLoaded()

  _G.logger:info(NAME_OF_MODULE .. ': Try to initially load parameter from CSK_PersistentData module.')
  if string.sub(CSK_PersistentData.getVersion(), 1, 1) == '1' then

    _G.logger:warning(NAME_OF_MODULE .. ': CSK_PersistentData module is too old and will not work. Please update CSK_PersistentData module.')

    liveConnect_Model.persistentModuleAvailable = false
  else

    local parameterName, loadOnReboot = CSK_PersistentData.getModuleParameterName(NAME_OF_MODULE)

    if parameterName then
      liveConnect_Model.parametersName = parameterName
      liveConnect_Model.parameterLoadOnReboot = loadOnReboot
    end

    if liveConnect_Model.parameterLoadOnReboot then
      loadParameters()
    end
    Script.notifyEvent('LiveConnect_OnDataLoadedOnReboot')
  end
end
Script.register("CSK_PersistentData.OnInitialDataLoaded", handleOnInitialDataLoaded)

return setLiveConnect_Model_Handle