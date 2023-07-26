---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter
--*****************************************************************
-- Inside of this script, you will find the module definition
-- including its parameters and functions
--*****************************************************************

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************
local nameOfModule = 'CSK_DateTime'

local dateTime_Model = {}

-- Check if CSK_UserManagement module can be used if wanted
dateTime_Model.userManagementModuleAvailable = CSK_UserManagement ~= nil or false

-- Check if CSK_PersistentData module can be used if wanted
dateTime_Model.persistentModuleAvailable = CSK_PersistentData ~= nil or false

-- Default values for persistent data
-- If available, following values will be updated from data of CSK_PersistentData module (check CSK_PersistentData module for this)
dateTime_Model.parametersName = 'CSK_DateTime_Parameter' -- name of parameter dataset to be used for this module
dateTime_Model.parameterLoadOnReboot = false -- Status if parameter dataset should be loaded on app/device reboot

-- Check if running on Emulator / SAE -> if so it is not possible to setup time
local typeName = Engine.getTypeName()

if typeName == 'AppStudioEmulator' or typeName == 'SICK AppEngine' then
  dateTime_Model.setupActive = false
else
  dateTime_Model.setupActive = true
end

-- Load script to communicate with the DateTime_Model interface and give access
-- to the DateTime_Model object.
-- Check / edit this script to see/edit functions which communicate with the UI
local setDateTime_ModelHandle = require('Configuration/DateTime/DateTime_Controller')
setDateTime_ModelHandle(dateTime_Model)

--Loading helper functions if needed
dateTime_Model.helperFuncs = require('Configuration/DateTime/helper/funcs')

-- Get DateTime
local day, month, year, hour, min, sec = DateTime.getDateTimeValuesLocal()

-- Values for manual setup of time
dateTime_Model.year = year
dateTime_Model.month = month
dateTime_Model.day = day
dateTime_Model.hour = hour
dateTime_Model.min = min
dateTime_Model.sec = sec

dateTime_Model.timezoneList = {} -- List of timezones
table.insert(dateTime_Model.timezoneList, 'Etc/GMT')
for i=1, 12 do
  table.insert(dateTime_Model.timezoneList, 'Etc/GMT+' .. tostring(i))
  table.insert(dateTime_Model.timezoneList, 'Etc/GMT-' .. tostring(i))
end

dateTime_Model.bootUpTimezone = DateTime.getTimeZone() -- Timezone used within bootUp
table.insert(dateTime_Model.timezoneList, tostring(dateTime_Model.bootUpTimezone))
dateTime_Model.timezoneJsonList = dateTime_Model.helperFuncs.createStringList(dateTime_Model.timezoneList) -- List of timezones for UI

dateTime_Model.ntpActive = false -- Should NTP be used for time? --> This does not mean, that there is an successfull NTP connection
dateTime_Model.isTimeSet = false -- Check if time was set since bootup, e.g. limited possibilty to check if NTP time was set but can not be differentiated from normal time setup

-- Check if NTP is supported on device
if _G.availableAPIs.specific then
  dateTime_Model.ntpClient = NTPClient.create() -- optional NTP client
end

dateTime_Model.interfaces = Engine.getEnumValues("EthernetInterfaces") -- Available interfaces of device running the app
dateTime_Model.interfaceList = dateTime_Model.helperFuncs.createStringList(dateTime_Model.interfaces)

-- Parameters to be saved permanently if wanted
dateTime_Model.parameters = {}

dateTime_Model.parameters.timezone = dateTime_Model.bootUpTimezone

dateTime_Model.parameters.ntpServerIP = "141.2.22.74" -- IP of test NTP server
dateTime_Model.parameters.ntpServerPort = 123 -- NTP port
dateTime_Model.parameters.ntpApplyEnabled = true --  timestamp received by NTP should be applied to the system time 
dateTime_Model.parameters.interface = dateTime_Model.interfaces[1] -- Select first available ETH interface for NTP
dateTime_Model.parameters.ntpPeriodicUpdate = true -- periodic update of NTP
dateTime_Model.parameters.ntpTimeout = 1000 -- NTP timeout
dateTime_Model.parameters.systemTimeSource = 'MANUAL'  -- time source for system time: 'NTP', 'MANUAL'

--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************
--*************************************************************************
--********************** End Function Scope *******************************
--*************************************************************************

return dateTime_Model
