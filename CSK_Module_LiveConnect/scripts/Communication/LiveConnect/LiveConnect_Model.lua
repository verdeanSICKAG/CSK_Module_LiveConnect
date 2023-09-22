---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter
--*****************************************************************
-- Inside of this script, you will find the module definition
-- including its parameters and functions
--*****************************************************************

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************

-------------------------------------------------------------------------------------
-- Variables
local liveConnect_Model = {}
local m_json = require("Communication.LiveConnect.utils.Lunajson")
local m_iccClientObject = require("Communication.LiveConnect.ICCClientObject")

-------------------------------------------------------------------------------------
-- Constant values
local NAME_OF_MODULE = 'CSK_LiveConnect'
local DEFAULT_PART_NUMBER = "1111222"
local DEFAULT_SERIAL_NUMBER = "12345678"
local TDCE_API_URL = "200.200.200.1/devicemanager/api/v1/system"
local TDCE_API_PORT = 80

-- Check if CSK_UserManagement module can be used if wanted
liveConnect_Model.userManagementModuleAvailable = CSK_UserManagement ~= nil or false

-- Check if CSK_PersistentData module can be used if wanted
liveConnect_Model.persistentModuleAvailable = CSK_PersistentData ~= nil or false

-- Default values for persistent data
-- If available, following values will be updated from data of CSK_PersistentData module (check CSK_PersistentData module for this)
liveConnect_Model.parametersName = 'CSK_LiveConnect_Parameter' -- name of parameter dataset to be used for this module
liveConnect_Model.parameterLoadOnReboot = true -- Status if parameter dataset should be loaded on app/device reboot

-- Load script to communicate with the ModuleName_Model interface and give access
-- to the ModuleName_Model object.
-- Check / edit this script to see/edit functions which communicate with the UI
local setLiveConnect_ModelHandle = require('Communication/LiveConnect/LiveConnect_Controller')
setLiveConnect_ModelHandle(liveConnect_Model)

--Loading helper functions if needed
liveConnect_Model.helperFuncs = require('Communication/LiveConnect/helper/funcs')

-- Serve API in global scope
liveConnect_Model.iccClient = nil

-- Parameters to be saved permanently if wanted
liveConnect_Model.parameters = {}
liveConnect_Model.parameters.cloudSystem = "prod"; -- Stage of the current connection (prod, int, dev)
liveConnect_Model.parameters.discoveryTimeoutMs = 3000; -- Device discovery timeout
liveConnect_Model.parameters.tokenTimeoutMs = 8000; -- Token timeout
liveConnect_Model.parameters.processIntervalMs = 5000; -- Reaction time to notice status changes of the LiveConnect connection
liveConnect_Model.parameters.mqttKeepAliveIntervalMs = 2000; -- MQTT keep alive interval
liveConnect_Model.parameters.mqttConnectTimeoutMs = 2500; -- MQTT connection timeout 
liveConnect_Model.parameters.mqttMessageForwardingIntervalMs = 100; -- MQTT message forwarding interval
liveConnect_Model.parameters.mqttMessageQueueMaxLength = 100; -- Number of telegrams to be temporarily stored as soon as LiveConnect is interrupted
liveConnect_Model.parameters.partNumber = DEFAULT_PART_NUMBER -- Part number from the gateway device
liveConnect_Model.parameters.serialNumber = DEFAULT_SERIAL_NUMBER -- Serial number from the gateway device

-------------------------------------------------------------------------------------
-- Checks if a string starts with given character
---@param str string String to check
---@param start int Start position
local function isStringStartsWith(str, start)
  return str:sub(1, #start) == start
end

-------------------------------------------------------------------------------------
-- Get system information from a TDC-E via HTTP call
local function getTdceSystemInfo()
  local l_client = HTTPClient.create()
  if not l_client then
    _G.logger:warning(NAME_OF_MODULE .. ": Can't create HTTP client handle")
    return nil
  end

  -- Create request
  local l_request = HTTPClient.Request.create()
  l_request:setURL(TDCE_API_URL)
  l_request:setPort(TDCE_API_PORT)
  l_request:setMethod('GET')

  -- Execute request
  local l_response = l_client:execute(l_request)

  -- Check success
  local l_success = l_response:getSuccess()
  if not l_success then
    _G.logger:info(NAME_OF_MODULE .. ": Can't get system information from system (" .. l_response:getError() .. ")")
    return nil
  else
    if isStringStartsWith(l_response:getContent(), "{") then
      local l_systemData = m_json.decode(l_response:getContent())
      return l_systemData
    else
      -- Response is not from type json
      return nil
    end
  end
end

-- Get part number of the device
local function getPartNumber()
  local l_partNumber
  -- Get part number from "Engine" crown (available for SIM platforms)
  if Engine and Engine.getPartNumber then
    l_partNumber = Engine.getPartNumber()

  -- Engine.getPartNumber crown is not available. Check if a TDC-E is used?
  else
    -- Get part number from from TDC-E API
    local l_tdceSystemInfo = getTdceSystemInfo()
    if l_tdceSystemInfo ~= nil then
      l_partNumber = l_tdceSystemInfo.orderNo
    end
  end

  -- Use default part number (e.g. AppEngine software product)
  if l_partNumber == nil or l_partNumber == "" then
    _G.logger:warning(NAME_OF_MODULE .. ": Can't read a valid part number from device, use default")
    l_partNumber = DEFAULT_PART_NUMBER
  end

  return l_partNumber
end
liveConnect_Model.parameters.partNumber = getPartNumber()

-- Get serial number of the device
local function getSerialNumber()
  local l_serialNumber
  -- Get serial number from "Engine" crown (available for SIM platforms)
  if Engine and Engine.getSerialNumber then
    l_serialNumber = Engine.getSerialNumber()

  -- Engine.getSerialNumber crown is not available. Check if a TDC-E is used?
  else
    -- Get serial number from from TDC-E API
    local l_tdceSystemInfo = getTdceSystemInfo()
    if l_tdceSystemInfo ~= nil then
      l_serialNumber = l_tdceSystemInfo.serialNo
    end
  end

  -- Use default serial number (e.g. AppEngine software product)
  if l_serialNumber == nil or l_serialNumber == "" then
    _G.logger:warning(NAME_OF_MODULE .. ": Can't read a valid serial number from device, use default")
    l_serialNumber = DEFAULT_SERIAL_NUMBER
  end

  return l_serialNumber
end
liveConnect_Model.parameters.serialNumber = getSerialNumber()

--**************************************************************************
--********************** End Global Scope **********************************

--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

-------------------------------------------------------------------------------------
-- Create ICC Client object which encapsulates all necessary functionality
function liveConnect_Model.createIccClient()
  _G.logger:info(NAME_OF_MODULE .. ": Create ICC Client")
  liveConnect_Model.iccClient = m_iccClientObject.create()

  liveConnect_Model.iccClient:addMainCapabilities() -- Add capabilities of the gateway device
  liveConnect_Model.iccClient:enable()

  local suc = Script.notifyEvent("LiveConnect_OnClientInitialized")
end

return liveConnect_Model