---@diagnostic disable: param-type-mismatch
-------------------------------------------------------------------------------------
-- Variable declarations
local m_object = {}
local m_json = require("Communication.LiveConnect.utils.Lunajson")

-------------------------------------------------------------------------------------
-- Failed table lookups on the instances should fallback to the class table, to get methods
m_object.__index = m_object

-------------------------------------------------------------------------------------
-- Determines a part of a string split by a given delimiter character
-- @stringSplit(s:string,delimiter:string):string
local function stringSplit(s, delimiter)
  local l_result = {}
  for match in string.gmatch(s, "([^" .. delimiter .. "]+)") do
    table.insert(l_result, match)
  end
  return l_result
end

-------------------------------------------------------------------------------------
-- Create profile object
function m_object.create(topic)
  local self = setmetatable({}, m_object)
  self.profileList = {}

  local l_profile = CSK_LiveConnect.MQTTProfile.create()
  CSK_LiveConnect.MQTTProfile.setUUID(l_profile, "7fbeb4de-d496-45b8-95a4-8f92bc01a0a0")
  CSK_LiveConnect.MQTTProfile.setName(l_profile, "Capabilities")
  CSK_LiveConnect.MQTTProfile.setDescription(l_profile, "The SICK Standard Capabilities MQTT profile.")
  CSK_LiveConnect.MQTTProfile.setBaseTopic(l_profile, topic)
  CSK_LiveConnect.MQTTProfile.setAsyncAPISpecification(l_profile, File.open("resources/profiles/mqtt_capabilities.yaml", "rb"):read())
  CSK_LiveConnect.MQTTProfile.setVersion(l_profile, "0.1.2.20181016150000A")

  self.profile = l_profile

  return self
end

-------------------------------------------------------------------------------------
-- Get profile data
function m_object.getPayload(self)
  local l_profileTable = {}
  for _, profile in pairs(self.profileList) do
    local l_profileInfo = {}
    l_profileInfo['id'] = CSK_LiveConnect.MQTTProfile.getUUID(profile)
    l_profileInfo['name'] = CSK_LiveConnect.MQTTProfile.getName(profile)
    l_profileInfo['description'] = CSK_LiveConnect.MQTTProfile.getDescription(profile)
    l_profileInfo["baseTopic"] = CSK_LiveConnect.MQTTProfile.getBaseTopic(profile)

    local l_version = stringSplit(CSK_LiveConnect.MQTTProfile.getVersion(profile), ".")
    l_profileInfo['version'] = {}

    -- Major
    if l_version[1] ~= nil then
      l_profileInfo['version']["major"] = tonumber(l_version[1])
    end

  	-- Minor
    if l_version[2] ~= nil then
      l_profileInfo['version']["minor"] = tonumber(l_version[2])
    end

  	-- Patch
    if l_version[3] ~= nil then
      l_profileInfo['version']["patch"] = tonumber(l_version[3])
    end

    -- Qualifier
    if l_version[4] ~= nil then
      l_profileInfo['version']["qualifier"] = l_version[4]
    end

    table.insert(l_profileTable, l_profileInfo)
  end

  return m_json.encode(l_profileTable)
end

-------------------------------------------------------------------------------------
-- Add profile
function m_object.addProfile(self, profile)
  table.insert(self.profileList, profile)
end

-------------------------------------------------------------------------------------
-- Return local function to be used it in other scripts
return m_object