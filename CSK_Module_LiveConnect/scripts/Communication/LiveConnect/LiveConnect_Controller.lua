---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter

--***************************************************************
-- Inside of this script, you will find the necessary functions,
-- variables and events to communicate with the LiveConnect_Model
--***************************************************************

--**************************************************************************
--************************ Start Global Scope ******************************
--**************************************************************************
local nameOfModule = 'CSK_LiveConnect'

-- Timer to update UI via events after page was loaded
local tmrLiveConnect = Timer.create()
tmrLiveConnect:setExpirationTime(300)
tmrLiveConnect:setPeriodic(false)

-- Reference to global handle
local liveConnect_Model

-- ************************ UI Events Start ********************************

-- Script.serveEvent("CSK_LiveConnect.OnNewEvent", "LiveConnect_OnNewEvent")
Script.serveEvent("CSK_LiveConnect.OnNewStatusLoadParameterOnReboot", "LiveConnect_OnNewStatusLoadParameterOnReboot")
Script.serveEvent("CSK_LiveConnect.OnPersistentDataModuleAvailable", "LiveConnect_OnPersistentDataModuleAvailable")
Script.serveEvent("CSK_LiveConnect.OnNewParameterName", "LiveConnect_OnNewParameterName")
Script.serveEvent("CSK_LiveConnect.OnDataLoadedOnReboot", "LiveConnect_OnDataLoadedOnReboot")

Script.serveEvent('CSK_LiveConnect.OnUserLevelOperatorActive', 'LiveConnect_OnUserLevelOperatorActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelMaintenanceActive', 'LiveConnect_OnUserLevelMaintenanceActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelServiceActive', 'LiveConnect_OnUserLevelServiceActive')
Script.serveEvent('CSK_LiveConnect.OnUserLevelAdminActive', 'LiveConnect_OnUserLevelAdminActive')

-- ...

-- ************************ UI Events End **********************************

--[[
--- Some internal code docu for local used function
local function functionName()
  -- Do something

end
]]

--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

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

--- Function to get access to the liveConnect_Model object
---@param handle handle Handle of liveConnect_Model object
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

--- Function to update user levels
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

--- Function to send all relevant values to UI on resume
local function handleOnExpiredTmrLiveConnect()

  updateUserLevel()

  -- Script.notifyEvent("LiveConnect_OnNewEvent", false)

  Script.notifyEvent("LiveConnect_OnNewStatusLoadParameterOnReboot", liveConnect_Model.parameterLoadOnReboot)
  Script.notifyEvent("LiveConnect_OnPersistentDataModuleAvailable", liveConnect_Model.persistentModuleAvailable)
  Script.notifyEvent("LiveConnect_OnNewParameterName", liveConnect_Model.parametersName)
  -- ...
end
Timer.register(tmrLiveConnect, "OnExpired", handleOnExpiredTmrLiveConnect)

-- ********************* UI Setting / Submit Functions Start ********************

local function pageCalled()
  updateUserLevel() -- try to hide user specific content asap
  tmrLiveConnect:start()
  return ''
end
Script.serveFunction("CSK_LiveConnect.pageCalled", pageCalled)

--[[
local function setSomething(value)
  _G.logger:info(nameOfModule .. ": Set new value = " .. value)
  liveConnect_Model.varA = value
end
Script.serveFunction("CSK_LiveConnect.setSomething", setSomething)
]]

-- *****************************************************************
-- Following function can be adapted for CSK_PersistentData module usage
-- *****************************************************************

local function setParameterName(name)
  _G.logger:info(nameOfModule .. ": Set parameter name: " .. tostring(name))
  liveConnect_Model.parametersName = name
end
Script.serveFunction("CSK_LiveConnect.setParameterName", setParameterName)

local function sendParameters()
  if liveConnect_Model.persistentModuleAvailable then
    CSK_PersistentData.addParameter(liveConnect_Model.helperFuncs.convertTable2Container(liveConnect_Model.parameters), liveConnect_Model.parametersName)
    CSK_PersistentData.setModuleParameterName(nameOfModule, liveConnect_Model.parametersName, liveConnect_Model.parameterLoadOnReboot)
    _G.logger:info(nameOfModule .. ": Send LiveConnect parameters with name '" .. liveConnect_Model.parametersName .. "' to CSK_PersistentData module.")
    CSK_PersistentData.saveData()
  else
    _G.logger:warning(nameOfModule .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_LiveConnect.sendParameters", sendParameters)

local function loadParameters()
  if liveConnect_Model.persistentModuleAvailable then
    local data = CSK_PersistentData.getParameter(liveConnect_Model.parametersName)
    if data then
      _G.logger:info(nameOfModule .. ": Loaded parameters from CSK_PersistentData module.")
      liveConnect_Model.parameters = liveConnect_Model.helperFuncs.convertContainer2Table(data)
      -- If something needs to be configured/activated with new loaded data, place this here:
      -- ...
      -- ...

      CSK_LiveConnect.pageCalled()
    else
      _G.logger:warning(nameOfModule .. ": Loading parameters from CSK_PersistentData module did not work.")
    end
  else
    _G.logger:warning(nameOfModule .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_LiveConnect.loadParameters", loadParameters)

local function setLoadOnReboot(status)
  liveConnect_Model.parameterLoadOnReboot = status
  _G.logger:info(nameOfModule .. ": Set new status to load setting on reboot: " .. tostring(status))
end
Script.serveFunction("CSK_LiveConnect.setLoadOnReboot", setLoadOnReboot)

--- Function to react on initial load of persistent parameters
local function handleOnInitialDataLoaded()

  if string.sub(CSK_PersistentData.getVersion(), 1, 1) == '1' then

    _G.logger:warning(nameOfModule .. ': CSK_PersistentData module is too old and will not work. Please update CSK_PersistentData module.')

    liveConnect_Model.persistentModuleAvailable = false
  else

    local parameterName, loadOnReboot = CSK_PersistentData.getModuleParameterName(nameOfModule)

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

-- *************************************************
-- END of functions for CSK_PersistentData module usage
-- *************************************************

return setLiveConnect_Model_Handle

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************

