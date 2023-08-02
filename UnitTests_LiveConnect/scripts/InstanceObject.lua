---@diagnostic disable: missing-parameter, redundant-parameter, param-type-mismatch, undefined-field

-------------------------------------------------------------------------------------
-- Variable declarations
local m_unitTestInstance = {}

-------------------------------------------------------------------------------------
-- Failed table lookups on the instances should fallback to the class table, to get methods
m_unitTestInstance.__index = m_unitTestInstance

local function getParamList(self)
  local l_params = {}
  for k,v in pairs(self.params) do
    local l_param = UnitTests_LiveConnect.TestParams.create()
    l_param:setName(k)
    l_param:setValue(v)
    table.insert(l_params, l_param)
  end

  return l_params
end

-------------------------------------------------------------------------------------
-- Create unit test instance object
function m_unitTestInstance.create(testScripts)
  local self = setmetatable({}, m_unitTestInstance)
  self.params = {}
  self.testScripts = testScripts
  self.luaUnit = require('utils/LuaUnit')

  for _,scriptName in pairs(self.testScripts) do
    require(scriptName)
  end

  self.runner = self.luaUnit.LuaUnit.new()
  self.runner:setOutputType("tap")

  Script.serveFunction('UnitTests_LiveConnect.getTestParams', function() return getParamList(self) end)

  return self
end

-------------------------------------------------------------------------------------
-- Set param
function m_unitTestInstance.setTestParam(self, param)
  self.params[param.name] = param.value
end

-------------------------------------------------------------------------------------
-- Get params as table
function m_unitTestInstance.getTestParams(self)
  return self.params
end

-------------------------------------------------------------------------------------
-- Start tests
function m_unitTestInstance.run(self)
  local l_notSuccessCount = self.runner:runSuite()

  if l_notSuccessCount == 0 then
    return true
  else
    return false
  end
end

------------------------------------------------------------------------
-- Return local function to be used it in other scripts
return m_unitTestInstance