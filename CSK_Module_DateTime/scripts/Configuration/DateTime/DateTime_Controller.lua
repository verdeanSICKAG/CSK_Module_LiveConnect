---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter

--***************************************************************
-- Inside of this script, you will find the necessary functions,
-- variables and events to communicate with the DateTime_Model
--***************************************************************

--**************************************************************************
--************************ Start Global Scope ******************************
--**************************************************************************
local nameOfModule = 'CSK_DateTime'

-- Timer to update UI via events after page was loaded
local tmrDateTime = Timer.create()
tmrDateTime:setExpirationTime(300)
tmrDateTime:setPeriodic(false)

-- Reference to global handle
local dateTime_Model

-- ************************ UI Events Start ********************************

Script.serveEvent("CSK_DateTime.OnNewLocalTime", "DateTime_OnNewLocalTime")
Script.serveEvent("CSK_DateTime.OnNewUTCTime", "DateTime_OnNewUTCTime")
Script.serveEvent("CSK_DateTime.OnNewDateTime", "DateTime_OnNewDateTime")

Script.serveEvent('CSK_DateTime.OnNewTimezoneList', 'DateTime_OnNewTimezoneList')
Script.serveEvent('CSK_DateTime.OnNewStatusTimezone', 'DateTime_OnNewStatusTimezone')

Script.serveEvent("CSK_DateTime.OnNewYear", "DateTime_OnNewYear")
Script.serveEvent("CSK_DateTime.OnNewMonth", "DateTime_OnNewMonth")
Script.serveEvent("CSK_DateTime.OnNewDay", "DateTime_OnNewDay")
Script.serveEvent("CSK_DateTime.OnNewHour", "DateTime_OnNewHour")
Script.serveEvent("CSK_DateTime.OnNewMinute", "DateTime_OnNewMinute")
Script.serveEvent("CSK_DateTime.OnNewSecond", "DateTime_OnNewSecond")

Script.serveEvent('CSK_DateTime.OnNewStatusNTPActive', 'DateTime_OnNewStatusNTPActive')
Script.serveEvent('CSK_DateTime.OnNewStatusNTPServerIP', 'DateTime_OnNewStatusNTPServerIP')
Script.serveEvent('CSK_DateTime.OnNewStatusNTPServerPort', 'DateTime_OnNewStatusNTPServerPort')

Script.serveEvent('CSK_DateTime.OnNewStatusNTPApplyEnabled', 'DateTime_OnNewStatusNTPApplyEnabled')
Script.serveEvent('CSK_DateTime.OnNewInterfaceList', 'DateTime_OnNewInterfaceList')
Script.serveEvent('CSK_DateTime.OnNewStatusNTPInterface', 'DateTime_OnNewStatusNTPInterface')
Script.serveEvent('CSK_DateTime.OnNewStatusNTPPeriodicUpdateEnabled', 'DateTime_OnNewStatusNTPPeriodicUpdateEnabled')
Script.serveEvent('CSK_DateTime.OnNewStatusNTPTimeout', 'DateTime_OnNewStatusNTPTimeout')
Script.serveEvent('CSK_DateTime.OnNewStatusSystemTimeSource', 'DateTime_OnNewStatusSystemTimeSource')

Script.serveEvent('CSK_DateTime.OnNewStatusIsTimeSet', 'DateTime_OnNewStatusIsTimeSet')

Script.serveEvent("CSK_DateTime.OnNewStatusLoadParameterOnReboot", "DateTime_OnNewStatusLoadParameterOnReboot")
Script.serveEvent("CSK_DateTime.OnPersistentDataModuleAvailable", "DateTime_OnPersistentDataModuleAvailable")
Script.serveEvent("CSK_DateTime.OnDataLoadedOnReboot", "DateTime_OnDataLoadedOnReboot")
Script.serveEvent("CSK_DateTime.OnNewParameterName", "DateTime_OnNewParameterName")

Script.serveEvent("CSK_DateTime.OnUserLevelOperatorActive", "DateTime_OnUserLevelOperatorActive")
Script.serveEvent("CSK_DateTime.OnUserLevelMaintenanceActive", "DateTime_OnUserLevelMaintenanceActive")
Script.serveEvent("CSK_DateTime.OnUserLevelServiceActive", "DateTime_OnUserLevelServiceActive")
Script.serveEvent("CSK_DateTime.OnUserLevelAdminActive", "DateTime_OnUserLevelAdminActive")

-- ************************ UI Events End **********************************

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
  Script.notifyEvent("DateTime_OnUserLevelOperatorActive", status)
end

--- Function to react on status change of Maintenance user level
---@param status boolean Status if Maintenance level is active
local function handleOnUserLevelMaintenanceActive(status)
  Script.notifyEvent("DateTime_OnUserLevelMaintenanceActive", status)
end

--- Function to react on status change of Service user level
---@param status boolean Status if Service level is active
local function handleOnUserLevelServiceActive(status)
  Script.notifyEvent("DateTime_OnUserLevelServiceActive", status)
end

--- Function to react on status change of Admin user level
---@param status boolean Status if Admin level is active
local function handleOnUserLevelAdminActive(status)
  Script.notifyEvent("DateTime_OnUserLevelAdminActive", status)
end

--- Function to get access to the dateTime_Model object
---@param handle handle Handle of dateTime_Model object
local function setDateTime_Model_Handle(handle)
  dateTime_Model = handle
  if dateTime_Model.userManagementModuleAvailable then
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
  if dateTime_Model.userManagementModuleAvailable then
    -- Trigger CSK_UserManagement module to provide events regarding user role
    CSK_UserManagement.pageCalled()
  else
    -- If CSK_UserManagement is not active, show everything
    Script.notifyEvent("DateTime_OnUserLevelOperatorActive", true)
    Script.notifyEvent("DateTime_OnUserLevelMaintenanceActive", true)
    Script.notifyEvent("DateTime_OnUserLevelServiceActive", true)
    Script.notifyEvent("DateTime_OnUserLevelAdminActive", true)
  end
end

--- Function to send all relevant values to UI on resume
local function handleOnExpiredTmrDateTime()

  updateUserLevel()

  local localDay, localMonth, localYear, localHour, localMin, localSec = DateTime.getDateTimeValuesLocal()
  local utcDay, utcMonth, utcYear, utcHour, utcMin, utcSec = DateTime.getDateTimeValuesUTC()
  local dateTime = DateTime.getDateTime()

  local currentLocalTime = string.format( "%04u-%02u-%02uT%02u:%02u:%02u",
                                localYear, localMonth, localDay, localHour, localMin, localSec)

  local currentUtcTime = string.format( "%04u-%02u-%02uT%02u:%02u:%02u",
                                utcYear, utcMonth, utcDay, utcHour, utcMin, utcSec)


  Script.notifyEvent("DateTime_OnNewLocalTime", "DateTimeValuesLocal = " .. currentLocalTime)
  Script.notifyEvent("DateTime_OnNewUTCTime", "DateTimeValuesUTC = " .. currentUtcTime)
  Script.notifyEvent("DateTime_OnNewDateTime", "DateTime = " .. dateTime)

  Script.notifyEvent("DateTime_OnNewTimezoneList", dateTime_Model.timezoneJsonList)
  Script.notifyEvent("DateTime_OnNewStatusTimezone", dateTime_Model.parameters.timezone)

  Script.notifyEvent("DateTime_OnNewYear", dateTime_Model.year)
  Script.notifyEvent("DateTime_OnNewMonth", dateTime_Model.month)
  Script.notifyEvent("DateTime_OnNewDay", dateTime_Model.day)
  Script.notifyEvent("DateTime_OnNewHour", dateTime_Model.hour)
  Script.notifyEvent("DateTime_OnNewMinute", dateTime_Model.min)
  Script.notifyEvent("DateTime_OnNewSecond", dateTime_Model.sec)

  Script.notifyEvent("DateTime_OnNewStatusNTPActive", dateTime_Model.ntpActive)
  Script.notifyEvent("DateTime_OnNewStatusNTPServerIP", dateTime_Model.parameters.ntpServerIP)
  Script.notifyEvent("DateTime_OnNewStatusNTPServerPort", dateTime_Model.parameters.ntpServerPort)

  Script.notifyEvent("DateTime_OnNewInterfaceList", dateTime_Model.interfaceList)
  Script.notifyEvent("DateTime_OnNewStatusNTPInterface", dateTime_Model.parameters.interface)
  Script.notifyEvent("DateTime_OnNewStatusNTPApplyEnabled", dateTime_Model.parameters.ntpApplyEnabled)
  Script.notifyEvent("DateTime_OnNewStatusNTPPeriodicUpdateEnabled", dateTime_Model.parameters.ntpPeriodicUpdate)
  Script.notifyEvent("DateTime_OnNewStatusNTPTimeout", dateTime_Model.parameters.ntpTimeout)
  Script.notifyEvent("DateTime_OnNewStatusSystemTimeSource", dateTime_Model.parameters.systemTimeSource)

  dateTime_Model.isTimeSet = DateTime.isTimeSet()
  Script.notifyEvent("DateTime_OnNewStatusIsTimeSet", dateTime_Model.isTimeSet)

  Script.notifyEvent("DateTime_OnNewStatusLoadParameterOnReboot", dateTime_Model.parameterLoadOnReboot)
  Script.notifyEvent("DateTime_OnPersistentDataModuleAvailable", dateTime_Model.persistentModuleAvailable)
  Script.notifyEvent("DateTime_OnNewParameterName", dateTime_Model.parametersName)

end
Timer.register(tmrDateTime, "OnExpired", handleOnExpiredTmrDateTime)

-- ********************* UI Setting / Submit Functions Start ********************

local function pageCalled()
  updateUserLevel() -- try to hide user specific content asap
  tmrDateTime:start()
  return ''
end
Script.serveFunction("CSK_DateTime.pageCalled", pageCalled)

local function setYear(year)
  dateTime_Model.year = year
end
Script.serveFunction("CSK_DateTime.setYear", setYear)

local function setMonth(month)
  dateTime_Model.month = month
end
Script.serveFunction("CSK_DateTime.setMonth", setMonth)

local function setDay(day)
  dateTime_Model.day = day
end
Script.serveFunction("CSK_DateTime.setDay", setDay)

local function setHour(hour)
  dateTime_Model.hour = hour
end
Script.serveFunction("CSK_DateTime.setHour", setHour)

local function setMinute(minute)
  dateTime_Model.min = minute
end
Script.serveFunction("CSK_DateTime.setMinute", setMinute)

local function setSecond(second)
  dateTime_Model.sec = second
end
Script.serveFunction("CSK_DateTime.setSecond", setSecond)

local function setTime()
  if dateTime_Model.setupActive then
    _G.logger:info(nameOfModule .. ": Setting new time:")
    _G.logger:info(string.format( "%04u-%02u-%02uT%02u:%02u:%02u",
    dateTime_Model.year, dateTime_Model.month, dateTime_Model.day, dateTime_Model.hour, dateTime_Model.min, dateTime_Model.sec))
    DateTime.setDateTime(dateTime_Model.year, dateTime_Model.month, dateTime_Model.day, dateTime_Model.hour, dateTime_Model.min, dateTime_Model.sec)
    pageCalled()
  else
    _G.logger:warning(nameOfModule .. ": Setting timezone on SAE / Emulator not possible.")
    return false
  end
end
Script.serveFunction("CSK_DateTime.setTime", setTime)

local function setTimezone(zone)
  if dateTime_Model.setupActive then
    local suc = DateTime.setTimeZone(zone)
    if suc then
      _G.logger:info(nameOfModule .. ": Set new timezone = " .. zone)
      dateTime_Model.parameters.timezone = zone
    else
      _G.logger:warning(nameOfModule .. ": Was not able to set new timezone. ")
    end
    tmrDateTime:start()
    return suc
  else
    _G.logger:warning(nameOfModule .. ": Setting timezone on SAE / Emulator not possible.")
    return false
  end
end
Script.serveFunction('CSK_DateTime.setTimezone', setTimezone)

local function manualNTPRequest()
  if dateTime_Model.parameters.systemTimeSource == 'NTP' then
    _G.logger:info(nameOfModule .. ": Trigger NTP Request.")
    dateTime_Model.ntpClient:startManualRequest()
    tmrDateTime:start()
  end
end
Script.serveFunction('CSK_DateTime.manualNTPRequest', manualNTPRequest)

local function setNTPServerIP(server)
  dateTime_Model.parameters.ntpServerIP= server
  _G.logger:info(nameOfModule .. ": Preset NTP Server IP to " .. dateTime_Model.parameters.ntpServerIP)
  if dateTime_Model.parameters.systemTimeSource == 'NTP' then
    _G.logger:info(nameOfModule .. ": Set NTP Server Address.")
    dateTime_Model.ntpClient:setServerAddress(dateTime_Model.parameters.ntpServerIP)
  end
end
Script.serveFunction('CSK_DateTime.setNTPServerIP', setNTPServerIP)

local function setNTPServerPort(port)
  dateTime_Model.parameters.ntpServerPort= port
  _G.logger:info(nameOfModule .. ": Preset NTP Server Port to " .. dateTime_Model.parameters.ntpServerPort)
  if dateTime_Model.parameters.systemTimeSource == 'NTP' then
    _G.logger:info(nameOfModule .. ": Set NTP Server port.")
    dateTime_Model.ntpClient:setServerPort(dateTime_Model.parameters.ntpServerPort)
  end
end
Script.serveFunction('CSK_DateTime.setNTPServerPort', setNTPServerPort)

local function setNTPInterface(interface)
  dateTime_Model.parameters.interface= interface
  _G.logger:info(nameOfModule .. ": Preset NTP interface to " .. dateTime_Model.parameters.interface)
  if dateTime_Model.parameters.systemTimeSource == 'NTP' then
    _G.logger:info(nameOfModule .. ": Set NTP interface.")
    dateTime_Model.ntpClient:setInterface(dateTime_Model.parameters.interface)
  end
end
Script.serveFunction('CSK_DateTime.setNTPInterface', setNTPInterface)

local function setSystemTimeSource(source)

  if source == 'NTP' and _G.availableAPIs.specific then
    _G.logger:info(nameOfModule .. ": Set system time source to 'NTP'")
    dateTime_Model.parameters.systemTimeSource = 'NTP'
    dateTime_Model.ntpActive = true
    Script.notifyEvent("DateTime_OnNewStatusNTPActive", dateTime_Model.ntpActive)

    dateTime_Model.ntpClient:setInterface(dateTime_Model.parameters.interface)
    dateTime_Model.ntpClient:setServerAddress(dateTime_Model.parameters.ntpServerIP)
    dateTime_Model.ntpClient:setServerPort(dateTime_Model.parameters.ntpServerPort)
    dateTime_Model.ntpClient:setApplyEnabled(dateTime_Model.parameters.ntpApplyEnabled)
    dateTime_Model.ntpClient:setPeriodicUpdateEnabled(dateTime_Model.parameters.ntpPeriodicUpdate)
    dateTime_Model.ntpClient:setTimeout(dateTime_Model.parameters.ntpTimeout)

    dateTime_Model.ntpClient:setTimeSource(dateTime_Model.parameters.systemTimeSource)

    _G.logger:info(nameOfModule .. ": Interface = " .. tostring(dateTime_Model.parameters.interface)
                .. ", ServerIP = " .. tostring(dateTime_Model.parameters.ntpServerIP)
                .. ", ServerPort = " .. tostring(dateTime_Model.parameters.ntpServerPort)
                .. ", ApplyToSystemTime = " .. tostring(dateTime_Model.parameters.ntpApplyEnabled)
                .. ", PeriodicalUpdate = " .. tostring(dateTime_Model.parameters.ntpPeriodicUpdate)
                .. ", Timeout = " .. tostring(dateTime_Model.parameters.ntpTimeout))

    manualNTPRequest()
    tmrDateTime:start()
  elseif _G.availableAPIs.specific then
    _G.logger:info(nameOfModule .. ": Set system time source to 'MANUAL'")
    dateTime_Model.parameters.systemTimeSource = 'MANUAL'
    dateTime_Model.ntpActive = false
    dateTime_Model.ntpClient:setTimeSource(dateTime_Model.parameters.systemTimeSource)
    tmrDateTime:start()
  else
    _G.logger:info(nameOfModule .. ": NTP not supported. Keep system time source 'MANUAL'")
    tmrDateTime:start()
  end
end
Script.serveFunction('CSK_DateTime.setSystemTimeSource', setSystemTimeSource)

local function setNTPApplyEnabled(status)
  dateTime_Model.parameters.ntpApplyEnabled= status
  _G.logger:info(nameOfModule .. ": 'Preconfigure to apply NTP to system time: " .. tostring(status))
  if dateTime_Model.parameters.systemTimeSource == 'NTP' then
    _G.logger:info(nameOfModule .. ": Set status to apply NTP to system time to " .. tostring(status))
    dateTime_Model.ntpClient:setApplyEnabled(status)
  end
end
Script.serveFunction('CSK_DateTime.setNTPApplyEnabled', setNTPApplyEnabled)

local function setNTPPeriodicUpdate(status)
  dateTime_Model.parameters.ntpPeriodicUpdate= status
  _G.logger:info(nameOfModule .. ": Preconfigure periodic update of NTP: " .. tostring(status))
  if dateTime_Model.parameters.systemTimeSource == 'NTP' then
    _G.logger:info(nameOfModule .. ": Set periodic update of NTP to " .. tostring(status))
    dateTime_Model.ntpClient:setPeriodicUpdateEnabled(dateTime_Model.parameters.ntpPeriodicUpdate)
  end
end
Script.serveFunction('CSK_DateTime.setNTPPeriodicUpdate', setNTPPeriodicUpdate)

local function setNTPTimeout(timeout)
  dateTime_Model.parameters.ntpTimeout= timeout
  _G.logger:info(nameOfModule .. ": Preset NTP timeout to " .. tostring(timeout))
  if dateTime_Model.parameters.systemTimeSource == 'NTP' then
    _G.logger:info(nameOfModule .. ": Set NTP timeout to " .. tostring(timeout))
    dateTime_Model.ntpClient:setTimeout(timeout)
  end
end
Script.serveFunction('CSK_DateTime.setNTPTimeout', setNTPTimeout)

-- *****************************************************************
-- Following function can be adapted for CSK_PersistentData module usage
-- *****************************************************************

local function setParameterName(name)
  _G.logger:info(nameOfModule .. ": Set CSK_PersistentData parameter name to " .. name)
  dateTime_Model.parametersName = name
end
Script.serveFunction("CSK_DateTime.setParameterName", setParameterName)

local function sendParameters()
  if dateTime_Model.persistentModuleAvailable then
    CSK_PersistentData.addParameter(dateTime_Model.helperFuncs.convertTable2Container(dateTime_Model.parameters), dateTime_Model.parametersName)
    CSK_PersistentData.setModuleParameterName(nameOfModule, dateTime_Model.parametersName, dateTime_Model.parameterLoadOnReboot)
    _G.logger:info(nameOfModule .. ": Send DateTime parameters with name '" .. dateTime_Model.parametersName .. "' to CSK_PersistentData module.")
    CSK_PersistentData.saveData()
  else
    _G.logger:warning(nameOfModule .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_DateTime.sendParameters", sendParameters)

local function loadParameters()
  if dateTime_Model.persistentModuleAvailable then
    local data = CSK_PersistentData.getParameter(dateTime_Model.parametersName)
    if data then
      _G.logger:info(nameOfModule .. ": Loaded parameters from CSK_PersistentData module.")
      dateTime_Model.parameters = dateTime_Model.helperFuncs.convertContainer2Table(data)
      if dateTime_Model.parameters.timezone ~= '' and dateTime_Model.parameters.timezone ~= nil then
        local suc = setTimezone(dateTime_Model.parameters.timezone)
        if not suc then
          dateTime_Model.parameters.timezone = dateTime_Model.bootUpTimezone
        end
      end
      setSystemTimeSource(dateTime_Model.parameters.systemTimeSource)
      CSK_DateTime.pageCalled()
    else
      _G.logger:warning(nameOfModule .. ": Loading parameters from CSK_PersistentData module did not work.")
    end
  else
    _G.logger:warning(nameOfModule .. ": CSK_PersistentData module not available.")
  end
end
Script.serveFunction("CSK_DateTime.loadParameters", loadParameters)

local function setLoadOnReboot(status)
  dateTime_Model.parameterLoadOnReboot = status
  _G.logger:info(nameOfModule .. ": Set new status to load setting on reboot: " .. tostring(status))
end
Script.serveFunction("CSK_DateTime.setLoadOnReboot", setLoadOnReboot)

--- Function to react on initial load of persistent parameters
local function handleOnInitialDataLoaded()

  _G.logger:info(nameOfModule .. ': Try to initially load parameter from CSK_PersistentData module.')
  if string.sub(CSK_PersistentData.getVersion(), 1, 1) == '1' then

    _G.logger:warning(nameOfModule .. ': CSK_PersistentData module is too old and will not work. Please update CSK_PersistentData module.')
    dateTime_Model.persistentModuleAvailable = false
  else

    _G.logger:info(nameOfModule .. ": Initially loading parameters from CSK_PersistentData module.")
    local parameterName, loadOnReboot = CSK_PersistentData.getModuleParameterName(nameOfModule)

    if parameterName then
      dateTime_Model.parametersName = parameterName
      dateTime_Model.parameterLoadOnReboot = loadOnReboot
    end

    if dateTime_Model.parameterLoadOnReboot then
      loadParameters()
    end
    Script.notifyEvent('DateTime_OnDataLoadedOnReboot')
  end
end
Script.register("CSK_PersistentData.OnInitialDataLoaded", handleOnInitialDataLoaded)

-- *************************************************
-- END of functions for CSK_PersistentData module usage
-- *************************************************

return setDateTime_Model_Handle

--**************************************************************************
--**********************End Function Scope *********************************
--**************************************************************************

