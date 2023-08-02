-------------------------------------------------------------------------------------
-- Variable declarations
local m_instanceObject = require('InstanceObject')
local m_testInstance

-------------------------------------------------------------------------------------
-- Run AdapterIOLink tests
local function runTests(token)
  local l_success = false
  local l_testScripts = {"tests/UnitTestLiveConnect"} -- Define test scripts to run

  -- Create test instance
  if m_testInstance == nil then
    m_testInstance = m_instanceObject.create(l_testScripts)
  end

  -- Run test instance
  if m_testInstance ~= nil then
    m_testInstance:setTestParam({name = "token", value = token}) -- Define parameters
    l_success = m_testInstance:run()
  end

  return l_success
end

Script.serveFunction(Engine.getCurrentAppName() .. ".runTests", runTests)