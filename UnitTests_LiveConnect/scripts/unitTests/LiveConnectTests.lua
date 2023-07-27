-- ==================================================================================
--[[
Description:

--]]
-- ==================================================================================

-------------------------------------------------------------------------------------
-- Variables
local m_lu = require('utils/LuaUnit')
local m_params = {}
TestClass = {}

-------------------------------------------------------------------------------------
-- Constant values

-------------------------------------------------------------------------------------
-- Sleep [ms]
local function sleep(ms)
  local l_t0 = DateTime.getTimestamp()
  while DateTime.getTimestamp() - l_t0 <= ms do

  end
end

local function getParameterValue(name)
  local l_value
  for k,v in pairs(m_params) do
    if v:getName() == name then
      l_value = v:getValue()
      break
    end
  end

  return l_value
end


-------------------------------------------------------------------------------------
-- Setup
function TestClass:setUp()
  -- Load parameters
  m_params = UnitTests_LiveConnect.getTestParams()
end

-------------------------------------------------------------------------------------
-- Test-case: Pair device
function TestClass:testBool()
  print("Test-Case: Pair device")

  if CSK_LiveConnect.getConnectionStatus() ~= "Pairing" then
    -- Go offline
    CSK_LiveConnect.removePairing()
  end

  -- Wait if offline
  while CSK_LiveConnect.getConnectionStatus() ~= "Pairing" do

  end

  -- Go online
  CSK_LiveConnect.setToken(getParameterValue("token"))
  CSK_LiveConnect.startTokenValidation()

  -- Wait if offline
  while CSK_LiveConnect.getConnectionStatus() ~= "Online" do

  end








  m_lu.assertIsTrue(true)
end
