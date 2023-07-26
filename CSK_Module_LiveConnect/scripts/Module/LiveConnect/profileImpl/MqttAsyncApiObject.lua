---@diagnostic disable: param-type-mismatch
-------------------------------------------------------------------------------------
-- Variable declarations
local m_object = {}

-------------------------------------------------------------------------------------
-- Failed table lookups on the instances should fallback to the class table, to get methods
m_object.__index = m_object

-------------------------------------------------------------------------------------
-- Create profile object
function m_object.create(topic)
  local self = setmetatable({}, m_object)

  local l_profile = CSK_LiveConnect.MqttProfile.create()
  CSK_LiveConnect.MqttProfile.setUuid(l_profile, "e105d8e0-6c70-4f0a-abed-6f746e8328f9")
  CSK_LiveConnect.MqttProfile.setName(l_profile, "AsyncAPI")
  CSK_LiveConnect.MqttProfile.setDescription(l_profile, "This interface defines a standardized way to get an AsyncAPI based MQTT interface description for a SICK device.")
  CSK_LiveConnect.MqttProfile.setBaseTopic(l_profile, topic)
  CSK_LiveConnect.MqttProfile.setAsyncAPISpecification(l_profile, File.open("resources/profiles/mqtt_async_api.yaml", "rb"):read())
  CSK_LiveConnect.MqttProfile.setVersion(l_profile, "0.2.0.20220202150000A")

  self.profile = l_profile

  return self
end

-------------------------------------------------------------------------------------
-- Get profile data
function m_object.getPayload(self)
  return CSK_LiveConnect.MqttProfile.getAsyncAPISpecification(self.profile)
end

-------------------------------------------------------------------------------------
-- Return local function to be used it in other scripts
return m_object