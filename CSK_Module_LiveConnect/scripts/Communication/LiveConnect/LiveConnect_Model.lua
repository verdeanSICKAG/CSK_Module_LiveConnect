---@diagnostic disable: undefined-global, redundant-parameter, missing-parameter
--*****************************************************************
-- Inside of this script, you will find the module definition
-- including its parameters and functions
--*****************************************************************

--**************************************************************************
--**********************Start Global Scope *********************************
--**************************************************************************
local nameOfModule = 'CSK_LiveConnect'

local liveConnect_Model = {}

-- Check if CSK_UserManagement module can be used if wanted
liveConnect_Model.userManagementModuleAvailable = CSK_UserManagement ~= nil or false

-- Check if CSK_PersistentData module can be used if wanted
liveConnect_Model.persistentModuleAvailable = CSK_PersistentData ~= nil or false

-- Default values for persistent data
-- If available, following values will be updated from data of CSK_PersistentData module (check CSK_PersistentData module for this)
liveConnect_Model.parametersName = 'CSK_LiveConnect_Parameter' -- name of parameter dataset to be used for this module
liveConnect_Model.parameterLoadOnReboot = false -- Status if parameter dataset should be loaded on app/device reboot

-- Load script to communicate with the LiveConnect_Model interface and give access
-- to the LiveConnect_Model object.
-- Check / edit this script to see/edit functions which communicate with the UI
local setLiveConnect_ModelHandle = require('Communication/LiveConnect/LiveConnect_Controller')
setLiveConnect_ModelHandle(liveConnect_Model)

--Loading helper functions if needed
liveConnect_Model.helperFuncs = require('Communication/LiveConnect/helper/funcs')

-- Optionally check if specific API was loaded via
--[[
if _G.availableAPIs.specific then
-- ... doSomething ...
end
]]

--[[
-- Create parameters / instances for this module
liveConnect_Model.object = Image.create() -- Use any AppEngine CROWN
liveConnect_Model.counter = 1 -- Short docu of variable
liveConnect_Model.varA = 'value' -- Short docu of variable
--...
]]

-- Parameters to be saved permanently if wanted
liveConnect_Model.parameters = {}
--liveConnect_Model.parameters.paramA = 'paramA' -- Short docu of variable
--liveConnect_Model.parameters.paramB = 123 -- Short docu of variable
--...

--**************************************************************************
--********************** End Global Scope **********************************
--**************************************************************************
--**********************Start Function Scope *******************************
--**************************************************************************

--[[
-- Some internal code docu for local used function to do something
---@param content auto Some info text if function is not already served
local function doSomething(content)
  _G.logger:info(nameOfModule .. ": Do something")
  liveConnect_Model.counter = liveConnect_Model.counter + 1
end
liveConnect_Model.doSomething = doSomething
]]

--*************************************************************************
--********************** End Function Scope *******************************
--*************************************************************************

return liveConnect_Model
