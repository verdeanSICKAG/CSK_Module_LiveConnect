---@diagnostic disable: param-type-mismatch
-------------------------------------------------------------------------------------
-- Variable declarations
local m_object = {}
local m_json = require("Communication.LiveConnect.utils.Lunajson")

-------------------------------------------------------------------------------------
-- Failed table lookups on the instances should fallback to the class table, to get methods
m_object.__index = m_object

-------------------------------------------------------------------------------------
-- Create profile object
function m_object.create(topic, clientName, partNumber, serialNumber)
  local self = setmetatable({}, m_object)
  self.clientName = clientName
  self.partNumber = partNumber
  self.serialNumber = serialNumber

  local l_profile = CSK_LiveConnect.MQTTProfile.create()
  CSK_LiveConnect.MQTTProfile.setUUID(l_profile, "b2fe7196-3f15-4574-a2db-e5f90bac3db2")
  CSK_LiveConnect.MQTTProfile.setName(l_profile, "Device Identification")
  CSK_LiveConnect.MQTTProfile.setDescription(l_profile, "The SICK Standard Device Identification MQTT profile.")
  CSK_LiveConnect.MQTTProfile.setBaseTopic(l_profile, topic)
  CSK_LiveConnect.MQTTProfile.setAsyncAPISpecification(l_profile, File.open("resources/profiles/mqtt_identification.yaml", "rb"):read())
  CSK_LiveConnect.MQTTProfile.setVersion(l_profile, "0.1.2.20181016150000A")

  self.profile = l_profile

  return self
end

-------------------------------------------------------------------------------------
-- Get profile data
function m_object.getPayload(self)
  local l_indentification = {}
  l_indentification['name'] = self.clientName
  l_indentification['serialNumber'] = '' .. self.serialNumber
  l_indentification['orderNumber'] = '' .. self.partNumber

  l_indentification['hardwareVersion'] = {}
  l_indentification['hardwareVersion']['major'] = 0
  l_indentification['hardwareVersion']['minor'] = 1
  l_indentification['hardwareVersion']['patch'] = 1
  l_indentification['hardwareVersion']['qualifier'] = "1000A"

  l_indentification['firmwareVersion'] = {}
  l_indentification['firmwareVersion']['major'] = 0
  l_indentification['firmwareVersion']['minor'] = 1
  l_indentification['firmwareVersion']['patch'] = 1
  l_indentification['firmwareVersion']['qualifier'] = "1000A"

  return m_json.encode(l_indentification)
end

-------------------------------------------------------------------------------------
-- Return local function to be used it in other scripts
return m_object