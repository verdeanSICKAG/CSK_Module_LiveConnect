---@diagnostic disable: param-type-mismatch, undefined-global, redundant-parameter
--***********************************************************************************
-- Inside of this script, you will find the necessary functions,
-- variables and events to communicate with the LiveConnect model
--***********************************************************************************

-------------------------------------------------------------------------------------
-- Variables
local m_mqttCapabilitiesObject = require("Module.LiveConnect.profileImpl.MqttCapabilitiesObject")
local m_mqttIdentificationObject = require("Module.LiveConnect.profileImpl.MqttIdentificationObject")
local m_mqttAsyncApiObject = require("Module.LiveConnect.profileImpl.MqttAsyncApiObject")
local m_httpCapabilitiesObject = require("Module.LiveConnect.profileImpl.HttpCapabilitiesObject")
local m_httpApplicationObject = require("Module.LiveConnect.profileImpl.HttpApplicationObject")
local m_devices = {}
local m_clearValidateTokenResultTimer = Timer.create()
local m_validateTokenResult = ""

-------------------------------------------------------------------------------------
-- Constant values
local NAME_OF_MODULE = 'CSK_LiveConnect'
local WATCHDOG_ADD_PROFILE_MS = 10000

-- Timer to update UI via events after page was loaded
local m_tmrLiveConnect = Timer.create()
m_tmrLiveConnect:setExpirationTime(300)
m_tmrLiveConnect:setPeriodic(false)

-- Reference to global handle
local liveConnect_Model

-- **********************************************************************************
-- UI Events
-- **********************************************************************************

Script.serveEvent("CSK_LiveConnect.OnNewStatusLoadParameterOnReboot", "LiveConnect_OnNewStatusLoadParameterOnReboot")
Script.serveEvent("CSK_LiveConnect.OnPersistentDataModuleAvailable", "LiveConnect_OnPersistentDataModuleAvailable")
Script.serveEvent("CSK_LiveConnect.OnNewParameterName", "LiveConnect_OnNewParameterName")
Script.serveEvent("CSK_LiveConnect.OnDataLoadedOnReboot", "LiveConnect_OnDataLoadedOnReboot")

Script.serveEvent('CSK_LiveConnect.OnUserLevelOperatorActive', 'LiveConnect_OnUserLevelOperatorActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelMaintenanceActive', 'LiveConnect_OnUserLevelMaintenanceActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelServiceActive', 'LiveConnect_OnUserLevelServiceActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelAdminActive', 'LiveConnect_OnUserLevelAdminActive')

Script.serveEvent('CSK_LiveConnect.OnNewProfileAdded', 'LiveConnect_OnNewProfileAdded')

Script.serveEvent("CSK_LiveConnect.OnNewMqttKeepAliveInterval", 'LiveConnect_OnNewMqttKeepAliveInterval')
Script.serveEvent("CSK_LiveConnect.OnNewMqttConnectTimeout", 'LiveConnect_OnNewMqttConnectTimeout')
Script.serveEvent("CSK_LiveConnect.OnNewMqttMessageInterval", 'LiveConnect_OnNewMqttMessageInterval')
Script.serveEvent("CSK_LiveConnect.OnNewMqttQueueSize", 'LiveConnect_OnNewMqttQueueSize')
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
-- @handleOnUserLevelOperatorActive(status:bool):
local function handleOnUserLevelOperatorActive(status)
  Script.notifyEvent("LiveConnect_OnUserLevelOperatorActive", status)
end

-------------------------------------------------------------------------------------
-- @handleOnUserLevelMaintenanceActive(status:bool):
local function handleOnUserLevelMaintenanceActive(status)
  Script.notifyEvent("LiveConnect_OnUserLevelMaintenanceActive", status)
end

-------------------------------------------------------------------------------------
-- @handleOnUserLevelServiceActive(status:bool):
local function handleOnUserLevelServiceActive(status)
  Script.notifyEvent("LiveConnect_OnUserLevelServiceActive", status)
end

-------------------------------------------------------------------------------------
-- @handleOnUserLevelAdminActive(status:bool):
local function handleOnUserLevelAdminActive(status)
  Script.notifyEvent("LiveConnect_OnUserLevelAdminActive", status)
end

-------------------------------------------------------------------------------------
-- Function to get access to the LiveConnect object
---@param handle table
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

  Script.notifyEvent("LiveConnect_OnNewStatusLoadParameterOnReboot", liveConnect_Model.parameterLoadOnReboot)
  Script.notifyEvent("LiveConnect_OnPersistentDataModuleAvailable", liveConnect_Model.persistentModuleAvailable)
  Script.notifyEvent("LiveConnect_OnNewParameterName", liveConnect_Model.parametersName)

  Script.notifyEvent("LiveConnect_OnNewMqttConnectTimeout", tostring(liveConnect_Model.parameters.mqttConnectTimeoutMs))
  Script.notifyEvent("LiveConnect_OnNewMqttKeepAliveInterval", tostring(liveConnect_Model.parameters.mqttKeepAliveIntervalMs))
  Script.notifyEvent("LiveConnect_OnNewMqttMessageInterval", tostring(liveConnect_Model.parameters.mqttMessageForwardingIntervalMs))
  Script.notifyEvent("LiveConnect_OnNewMqttQueueSize", tostring(liveConnect_Model.parameters.mqttMessageQueueMaxLength))

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
local function createUuid()
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
    local l_success, l_errorMessage = liveConnect_Model.iccClient:validateToken(l_token)
    if (l_success) then
      liveConnect_Model.iccClient.softApprovalToken = ""
      publishValidateTokenResult("Registration successful")
    else
      publishValidateTokenResult("Token validation error: " .. l_errorMessage)
    end
  end
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
-- Get device URL which refers to the digital twin on the SICK AssetHub
---@return string
local function getDeviceUrl()
  local l_cloudSystem = liveConnect_Model.parameters.cloudSystem
  local l_deviceUuid = liveConnect_Model.iccClient.deviceUuid
  if l_deviceUuid == nil then
    return ""
  end

  if l_cloudSystem == "prod" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return string.format("https://assethub.cloud.sick.com/liveconnect/%s", l_deviceUuid)
  elseif l_cloudSystem == "int" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return string.format("https://assethub.int.sickag.cloud/liveconnect/%s", l_deviceUuid)
  elseif l_cloudSystem == "dev" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return string.format("https://assethub.dev.sickag.cloud/liveconnect/%s", l_deviceUuid)
  else
    return ""
  end
end
Script.serveFunction("CSK_LiveConnect.getDeviceUrl", getDeviceUrl)

-------------------------------------------------------------------------------------
-- Provides information about the information to be displayed on the UI page
---@return string
local function getCurrentView()
  local ret = liveConnect_Model.iccClient.deviceUuid
  if ret == nil then
    return "0" -- Show paring code and button 
  end
  return "1" -- Show device url and unpair buttons
end
Script.serveFunction("CSK_LiveConnect.UI.getCurrentView", getCurrentView)

-------------------------------------------------------------------------------------
-- Set soft approval token
---@param token string
local function setToken(token)
  _G.logger:info(NAME_OF_MODULE .. ": Set soft approval token (" .. token ..")")
  liveConnect_Model.iccClient.softApprovalToken = token
end
Script.serveFunction("CSK_LiveConnect.setToken", setToken)

-------------------------------------------------------------------------------------
-- Get status of the LiveConnect connection
---@result string
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
  local l_deviceUuid = createUuid()
  local l_deviceUrl;
  if l_isPeerDevice then
    l_deviceUrl = liveConnect_Model.iccClient.standardInterfaceServer .. "/gateway/" .. l_deviceUuid
  else
    l_deviceUrl = liveConnect_Model.iccClient.standardInterfaceServer
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
      uuid = l_deviceUuid,
      httpCapabilities = nil,
      mqttCapabilities = nil,
      mqttIdentification = nil,
      mqttAsyncApi = nil,
      isPeerDevice = l_isPeerDevice,
      partNumber = partNumber,
      serialNumber = serialNumber,
      url = l_deviceUrl
    }
  end

  return m_devices[l_index], l_isNewDevice
end

-------------------------------------------------------------------------------------
-- Add / update http profiles of a peer device
-- Create a new peer device if it doesn't already exist
---@param device table
---@param isNewDevice bool
---@param applicationProfile CSK_LiveConnect.HttpProfile
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
-- Add a MQTT application profile to the registered profile list
---@param partNumber string
---@param serialNumber string
---@param mqttProfile CSK_LiveConnect.HttpProfile
---@return string
local function addMqttProfile(partNumber, serialNumber, mqttProfile)
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
      local l_profileId = CSK_LiveConnect.MqttProfile.getUuid(l_device.mqttCapabilities.profile)
      local l_asyncApiTopic = string.format('%s/%s/%s', liveConnect_Model.iccClient.mqttTopicAsyncApi, l_profileId, l_device.uuid)
      local l_asyncApiPayload = CSK_LiveConnect.MqttProfile.getAsyncAPISpecification(l_device.mqttCapabilities.profile)
      liveConnect_Model.iccClient:addMqttTopic(l_asyncApiTopic, l_asyncApiPayload, "QOS1")
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
      liveConnect_Model.iccClient:addMqttTopic(l_deviceIdentificationTopic, l_deviceIdentificationPayload, "QOS1")

      -- Publish async api profile payload
      local l_profileId = CSK_LiveConnect.MqttProfile.getUuid(l_device.mqttIdentification.profile)
      local l_asyncApiTopic = string.format('%s/%s/%s', liveConnect_Model.iccClient.mqttTopicAsyncApi, l_profileId, l_device.uuid)
      local l_asyncApiPayload = CSK_LiveConnect.MqttProfile.getAsyncAPISpecification(l_device.mqttIdentification.profile)
      liveConnect_Model.iccClient:addMqttTopic(l_asyncApiTopic, l_asyncApiPayload, "QOS1")
    end

    -- Add async api profile
    if l_device.mqttAsyncApi == nil then
      _G.logger:fine(string.format("%s: Add MQTT async api profile to device (PN: %s | SN: %s)", NAME_OF_MODULE, l_device.partNumber, l_device.serialNumber))
      l_device.mqttAsyncApi = m_mqttAsyncApiObject.create(
        liveConnect_Model.iccClient.mqttTopicAsyncApi
      )

      l_device.mqttCapabilities:addProfile(l_device.mqttAsyncApi.profile)

      -- Publish async api profile payload
      local l_profileId = CSK_LiveConnect.MqttProfile.getUuid(l_device.mqttAsyncApi.profile)
      local l_asyncApiTopic = string.format('%s/%s/%s', liveConnect_Model.iccClient.mqttTopicAsyncApi, l_profileId, l_device.uuid)
      local l_asyncApiPayload = CSK_LiveConnect.MqttProfile.getAsyncAPISpecification(l_device.mqttAsyncApi.profile)
      liveConnect_Model.iccClient:addMqttTopic(l_asyncApiTopic, l_asyncApiPayload, "QOS1")
    end

    -- Add application profile to the capabilities
    l_device.mqttCapabilities:addProfile(mqttProfile)

    -- Publish async api profile payload
    local l_profileId = CSK_LiveConnect.MqttProfile.getUuid(mqttProfile)
    local l_asyncApiTopic = string.format('%s/%s/%s', liveConnect_Model.iccClient.mqttTopicAsyncApi, l_profileId, l_device.uuid)
    local l_asyncApiPayload = CSK_LiveConnect.MqttProfile.getAsyncAPISpecification(mqttProfile)
    liveConnect_Model.iccClient:addMqttTopic(l_asyncApiTopic, l_asyncApiPayload, "QOS1")

    -- Publish and update of the capabilities profile payload
    local l_capabilitiesTopic = string.format('%s/%s', liveConnect_Model.iccClient.mqttTopicBaseCapabilities, l_device.uuid)
    local l_capabilitiesPayload = l_device.mqttCapabilities:getPayload()
    liveConnect_Model.iccClient:addMqttTopic(l_capabilitiesTopic, l_capabilitiesPayload, "QOS1")

    Script.notifyEvent("LiveConnect_OnNewProfileAdded", mqttProfile:getName(), "asyncAPI")
    return l_device.uuid
  else
    _G.logger:warning(NAME_OF_MODULE .. ": Can't add MQTT profile, because the LiveConnect client is not yet initialized. The client needs 100ms to initialize itself.")

    ---@diagnostic disable-next-line: return-type-mismatch
    return nil
  end
end
Script.serveFunction("CSK_LiveConnect.addMqttProfile", addMqttProfile)

-------------------------------------------------------------------------------------
-- Add HTTP application profile
---@param partNumber string
---@param serialNumber string
---@param httpProfile CSK_LiveConnect.HttpProfile
local function addHttpProfile(partNumber, serialNumber, httpProfile)
  if liveConnect_Model.iccClient ~= nil then
    _G.logger:info(NAME_OF_MODULE .. ": Register HTTP profile (" .. httpProfile:getName() .. ")")
    local l_device, l_isNewDevice = getDevice(partNumber, serialNumber)

    if l_device.isPeerDevice then
      -- Add application profile
      local l_applicationProfile = m_httpApplicationObject.create(l_device.url, httpProfile)
      for serviceLocation, endpoint in pairs(l_applicationProfile:getEndpoints()) do
        liveConnect_Model.iccClient:addEndpoint(serviceLocation, endpoint)
      end
      liveConnect_Model.iccClient:addHttpProfilePeerDevice(l_applicationProfile.profile, partNumber, serialNumber)

      handlePeerDevice(l_device, l_isNewDevice, httpProfile)
    else
      -- Add application profile
      local l_applicationProfile = m_httpApplicationObject.create(l_device.url, httpProfile)
      for serviceLocation, endpoint in pairs(l_applicationProfile:getEndpoints()) do
        liveConnect_Model.iccClient:addEndpoint(serviceLocation, endpoint)
      end
      liveConnect_Model.iccClient:addHttpProfileGatewayDevice(l_applicationProfile.profile)

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
Script.serveFunction("CSK_LiveConnect.addHttpProfile", addHttpProfile)

-------------------------------------------------------------------------------------
-- Publish MQTT application data using part number and serial number
---@param topic string
---@param partNumber string
---@param serialNumber string
---@param payload string
local function publishMqttData(topic, partNumber, serialNumber, payload)
  -- Get meta information about the device
  local l_device = m_devices[partNumber .. serialNumber]

  if l_device ~= nil then
    -- Add uuid
    local l_topicWithUuid = string.format('%s/%s', topic, l_device.uuid)

    -- Add data to the mqtt message queue
    _G.logger:fine(string.format("%s: Publish MQTT data (%s): %s", NAME_OF_MODULE, l_topicWithUuid, payload))
    liveConnect_Model.iccClient:addMqttTopic(l_topicWithUuid, payload, "QOS1")
  end
end
Script.serveFunction("CSK_LiveConnect.publishMqttData", publishMqttData)

-------------------------------------------------------------------------------------
-- Publish MQTT application data using the device UUID
local function publishMqttDataById(topic, deviceUuid, payload)
  local l_device = nil
  for _, device in pairs(m_devices) do
    if (device.uuid == deviceUuid) then
      l_device = device
      break
    end
  end

  if l_device ~= nil then
    publishMqttData(topic, l_device.partNumber, l_device.serialNumber, payload)
  else
    _G.logger:warning(string.format("%s: Can't publish MQTT data. Device UUID (%s) can't be assigned", NAME_OF_MODULE, deviceUuid))
  end
end
Script.serveFunction("CSK_LiveConnect.publishMqttDataById", publishMqttDataById)

-------------------------------------------------------------------------------------
-- Check if the system clock is configured
---@return bool
local function isSystemClockConfigured()
  -- Check if time is set correctly
  -- Check if day 2001-09-09T01:46:40Z pasted
  local l_ret = DateTime.getUnixTime() >= 1000000000

  return l_ret
end


-------------------------------------------------------------------------------------
-- Check if the system clock is not configured
---@return bool
local function isNotSystemClockConfigured()
  return not isSystemClockConfigured()
end
Script.serveFunction("CSK_LiveConnect.UI.isNotSystemClockConfigured", isNotSystemClockConfigured)

-------------------------------------------------------------------------------------
-- Get status of the system clock
---@return string
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
-- Remove peer device
---@param partNumber string 
---@param serialNumber string 
local function removePeerDevice(partNumber, serialNumber)
  _G.logger:info(string.format("%s: Remove peer device (PN: %s / SN: %s)",NAME_OF_MODULE, partNumber, serialNumber))
  liveConnect_Model.iccClient:removePeerDevice(partNumber, serialNumber)
end
Script.serveFunction("CSK_LiveConnect.removePeerDevice", removePeerDevice)

-------------------------------------------------------------------------------------
-- Set queue size of the MQTT message queue
---@param queueSize string
local function setMqttMessageQueueSize(queueSize)
  _G.logger:info(string.format("%s: Set MQTT message queue size (%s)", NAME_OF_MODULE, queueSize))
  liveConnect_Model.parameters.mqttMessageQueueMaxLength = tonumber(queueSize)
end
Script.serveFunction("CSK_LiveConnect.setMqttMessageQueueSize", setMqttMessageQueueSize)

-------------------------------------------------------------------------------------
-- Set 
---@param keepAliveInterval string
local function setMqttKeepAliveInterval(keepAliveInterval)
  _G.logger:info(string.format("%s: Set MQTT keep alive interval (%sms)", NAME_OF_MODULE, keepAliveInterval))
  liveConnect_Model.parameters.mqttKeepAliveIntervalMs = tonumber(keepAliveInterval)
end
Script.serveFunction("CSK_LiveConnect.setMqttKeepAliveInterval", setMqttKeepAliveInterval)


-------------------------------------------------------------------------------------
-- Set 
---@param connectTimeout string
local function setMqttConnectTimeout(connectTimeout)
  _G.logger:info(string.format("%s: Set MQTT connect timeout (%sms)", NAME_OF_MODULE, connectTimeout))
  liveConnect_Model.parameters.mqttConnectTimeoutMs = tonumber(connectTimeout)
end
Script.serveFunction("CSK_LiveConnect.setMqttConnectTimeout", setMqttConnectTimeout)

-------------------------------------------------------------------------------------
-- Set 
---@param messageInterval string
local function setMqttMessageInterval(messageInterval)
  _G.logger:info(string.format("%s: Set MQTT message forwarding interval (%sms)", NAME_OF_MODULE, messageInterval))
  liveConnect_Model.parameters.mqttMessageForwardingIntervalMs = tonumber(messageInterval)
end
Script.serveFunction("CSK_LiveConnect.setMqttMessageInterval", setMqttMessageInterval)

-------------------------------------------------------------------------------------
-- Set process interval to notice status changes of the LiveConnect connection
---@param interval string
local function setProcessInterval(interval)
  _G.logger:info(string.format("%s: Set process interval (%sms)", NAME_OF_MODULE, interval))
  liveConnect_Model.parameters.processIntervalMs = tonumber(interval)
end
Script.serveFunction('CSK_LiveConnect.setProcessInterval', setProcessInterval)

-------------------------------------------------------------------------------------
-- Set timeout for the accepting of the pairing token
---@param timeout string
local function setTokenTimeout(timeout)
  _G.logger:info(string.format("%s: Set token timeout (%sms)", NAME_OF_MODULE, timeout))
  liveConnect_Model.parameters.tokenTimeoutMs = tonumber(timeout)
end
Script.serveFunction('CSK_LiveConnect.setTokenTimeout', setTokenTimeout)

-------------------------------------------------------------------------------------
-- Set device discovery timeout
---@param timeout string
local function setDeviceDiscoveryTimeout(timeout)
  _G.logger:info(string.format("%s: Set device discovery timeout (%sms)", NAME_OF_MODULE, timeout))
  liveConnect_Model.parameters.discoveryTimeoutMs = tonumber(timeout)
end
Script.serveFunction('CSK_LiveConnect.setDeviceDiscoveryTimeout', setDeviceDiscoveryTimeout)

-------------------------------------------------------------------------------------
-- Set part number of the gateway device
---@param partNumber string
local function setGatewayPartNumber(partNumber)
  _G.logger:info(string.format("%s: Set part number of the gateway device (%s)", NAME_OF_MODULE, partNumber))
  liveConnect_Model.parameters.partNumber = partNumber
end
Script.serveFunction('CSK_LiveConnect.setGatewayPartNumber', setGatewayPartNumber)

-------------------------------------------------------------------------------------
-- Get part number of the gateway device
---@return string
local function getGatewayPartNumber()
  return liveConnect_Model.parameters.partNumber
end
Script.serveFunction('CSK_LiveConnect.getGatewayPartNumber', getGatewayPartNumber)

-------------------------------------------------------------------------------------
-- Set serial number of the gateway device
---@param serialNumber string
local function setGatewaySerialNumber(serialNumber)
  _G.logger:info(string.format("%s: Set serial number of the gateway device (%s)", NAME_OF_MODULE, serialNumber))
  liveConnect_Model.parameters.serialNumber = serialNumber
end
Script.serveFunction('CSK_LiveConnect.setGatewaySerialNumber', setGatewaySerialNumber)

-------------------------------------------------------------------------------------
-- Get serial number of the gateway device
---@return string 
local function getGatewaySerialNumber()
  return liveConnect_Model.parameters.serialNumber
end
Script.serveFunction('CSK_LiveConnect.getGatewaySerialNumber', getGatewaySerialNumber)

-------------------------------------------------------------------------------------
-- Set cloud system (prod/int/dev)
---@param cloudSystem string
local function setCloudSystem(cloudSystem)
  _G.logger:info(string.format("%s: Set cloud system (%s)", NAME_OF_MODULE, cloudSystem))
  liveConnect_Model.parameters.cloudSystem = cloudSystem
end
Script.serveFunction('CSK_LiveConnect.setCloudSystem', setCloudSystem)

-------------------------------------------------------------------------------------
-- Get a list of all registered devices and profiles
---@return table devices 
local function getRegisteredProfiles()
  local l_devices = {}
  if liveConnect_Model.iccClient ~= nil then
    -- Add gateway device
    local l_gatewayDevice = CSK_LiveConnect.Device.create()
    l_gatewayDevice:setDeviceType("GATEWAY_DEVICE")
    l_gatewayDevice:setPartNumber(liveConnect_Model.parameters.partNumber)
    l_gatewayDevice:setSerialNumber(liveConnect_Model.parameters.serialNumber)
    l_gatewayDevice:setDeviceUuid(liveConnect_Model.iccClient.deviceUuid)
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
          l_peerDevice:setDeviceUuid(peerDevice.deviceUuid)

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
-- Get validate token result
---@return string status
local function getValidateTokenResult()
  return m_validateTokenResult
end
Script.serveFunction('CSK_LiveConnect.getValidateTokenResult', getValidateTokenResult)

-------------------------------------------------------------------------------------
-- Remove all registered profiles and devices
local function removeAllProfiles()
  _G.logger:info(NAME_OF_MODULE .. ": Removing all profiles and connected devices")
  m_devices = {}
  liveConnect_Model.iccClient:removeAllProfiles()

end
Script.serveFunction("CSK_LiveConnect.removeAllProfiles", removeAllProfiles)

-------------------------------------------------------------------------------------
-- Page called
---@return string
local function pageCalled()
  updateUserLevel() -- try to hide user specific content asap
  m_tmrLiveConnect:start()
  return ''
end
Script.serveFunction("CSK_LiveConnect.pageCalled", pageCalled)

-- **********************************************************************************
-- Start of functions for PersistentData module usage
-- **********************************************************************************

-------------------------------------------------------------------------------------
-- Set name of the parameter set
---@param name string
local function setParameterName(name)
  _G.logger:info(NAME_OF_MODULE .. ": Set parameter name: " .. tostring(name))
  liveConnect_Model.parametersName = tostring(name)
end
Script.serveFunction("CSK_LiveConnect.setParameterName", setParameterName)

-------------------------------------------------------------------------------------
-- Send parameters
local function sendParameters()
  if liveConnect_Model.persistentModuleAvailable then
    CSK_PersistentData.addParameter(liveConnect_Model.helperFuncs.convertTable2Container(liveConnect_Model.parameters), liveConnect_Model.parametersName)
    CSK_PersistentData.setModuleParameterName(NAME_OF_MODULE, liveConnect_Model.parametersName, liveConnect_Model.parameterLoadOnReboot)
    _G.logger:info(NAME_OF_MODULE .. ": Send LiveConnect parameters with name '" .. liveConnect_Model.parametersName .. "' to PersistentData module.")
    CSK_PersistentData.saveData()

    -- Reinit LiveConnect client to ensure that the parameters are accepted
    liveConnect_Model.iccClient:reinit()
  else
    _G.logger:warning(NAME_OF_MODULE .. ": PersistentData Module not available.")
  end
end
Script.serveFunction("CSK_LiveConnect.sendParameters", sendParameters)

-------------------------------------------------------------------------------------
-- Load parameters
local function loadParameters()
  if liveConnect_Model.persistentModuleAvailable then
    local data = CSK_PersistentData.getParameter(liveConnect_Model.parametersName)
    if data then
      _G.logger:info(NAME_OF_MODULE .. ": Loaded parameters from PersistentData module.")
      liveConnect_Model.parameters = liveConnect_Model.helperFuncs.convertContainer2Table(data)

      -- Reinit LiveConnect client to ensure that the parameters are accepted
      liveConnect_Model.iccClient:reinit()

      CSK_LiveConnect.pageCalled()
    else
      _G.logger:warning(NAME_OF_MODULE .. ": Loading parameters from PersistentData module did not work.")
    end
  else
    _G.logger:warning(NAME_OF_MODULE .. ": PersistentData Module not available.")
  end
end
Script.serveFunction("CSK_LiveConnect.loadParameters", loadParameters)

-------------------------------------------------------------------------------------
-- Set parameter load on reboot
---@param status bool
local function setLoadOnReboot(status)
  liveConnect_Model.parameterLoadOnReboot = status
  _G.logger:info(NAME_OF_MODULE .. ": Set new status to load setting on reboot: " .. tostring(status))
end
Script.serveFunction("CSK_LiveConnect.setLoadOnReboot", setLoadOnReboot)

-------------------------------------------------------------------------------------
-- Handle event "OnInitialDataLoaded"
local function handleOnInitialDataLoaded()
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