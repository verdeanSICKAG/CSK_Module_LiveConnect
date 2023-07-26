---@diagnostic disable: param-type-mismatch

-------------------------------------------------------------------------------------
-- Parameters
local m_json = require("utils.Lunajson")
local m_profileDistance = require("ProfileDistance")
local m_profileIdentification = require("ProfileIdentification")
local m_profileHttpTest = require("ProfileHttpTest")

-------------------------------------------------------------------------------------
-- Constant values
local PARAMETER_NAME = "liveConnectProfiles"

-------------------------------------------------------------------------------------
-- Determines a part of a string split by a given delimiter character
local function stringSplit(s, delimiter)
  local l_result = {}
  for match in string.gmatch(s, "([^" .. delimiter .. "]+)") do
    table.insert(l_result, match)
  end
  return l_result
end

-------------------------------------------------------------------------------------
-- Get a generated UUID
local function createUuid()
  local l_template ='xxxxxxxx'
  local l_uuid =  string.gsub(l_template, '[xy]', function (c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)

  return l_uuid
end

-------------------------------------------------------------------------------------
-- Handle profile data
local function handleProfileData(profileName, connectionType)
  local l_status = "OK"
  local l_profileScript = nil
  if profileName == "Distance" then
    if connectionType == "HTTP" or connectionType == "MQTT" then
      l_profileScript = m_profileDistance
    else
      l_status = "Connection type not supported for this profile"
    end

  -- Identification profile
  elseif profileName == "Identification" then
    if connectionType == "MQTT" then
      l_profileScript = m_profileIdentification
    else
      l_status = "Connection type not supported for this profile"
    end
  elseif profileName == "HttpTest" then
    if connectionType == "HTTP" then
      l_profileScript = m_profileHttpTest
    else
      l_status = "Connection type not supported for this profile"
    end
  else
    l_status = "Profile with the specified \"profileName\" was not found"
  end

  return l_status, l_profileScript
end


-------------------------------------------------------------------------------------
-- Get profile container from internal repository
local function getProfilesFromContext()
  -- Load container
  local l_profiles = {}
  local l_profilesContainer = CSK_PersistentData.getParameter(PARAMETER_NAME)
  if l_profilesContainer ~= nil then
    local l_parameters = Container.list(l_profilesContainer)
    for _,parameter in pairs(l_parameters) do
      local l_id = stringSplit(parameter, "_")
      if l_profiles[l_id[1]] == nil then
        l_profiles[l_id[1]] = {}
      end
      l_profiles[l_id[1]][l_id[2]] = Container.get(l_profilesContainer, parameter)
    end
  end

  return l_profiles
end

-------------------------------------------------------------------------------------
-- Save profiles
local function saveProfile(profileName, partNumber, serialNumber, connectionType, profile)
  -- Load container
  local l_profilesContainer = CSK_PersistentData.getParameter(PARAMETER_NAME)
  local l_uuid = createUuid()
  if l_profilesContainer == nil then
    l_profilesContainer = Container.create()
  end

  -- Add data to container
  Container.add(l_profilesContainer, l_uuid .. "_profile", profile)
  Container.add(l_profilesContainer, l_uuid .. "_partNumber", partNumber)
  Container.add(l_profilesContainer, l_uuid .. "_connectionType", connectionType)
  Container.add(l_profilesContainer, l_uuid .. "_serialNumber", serialNumber)
  Container.add(l_profilesContainer, l_uuid .. "_profileName", profileName)

  -- Save data
  CSK_PersistentData.addParameter(l_profilesContainer, PARAMETER_NAME)
  CSK_PersistentData.saveData()
end

-------------------------------------------------------------------------------------
-- Load profiles from context
local function loadProfiles()
  -- Load container
  local l_containers = getProfilesFromContext()
  if l_containers ~= nil then
    for _,container in pairs(l_containers) do
      local l_status, l_profileScript = handleProfileData(container.profileName, container.connectionType)
      if l_status == "OK" then
        if container.connectionType == "HTTP" then
          CSK_LiveConnect.addHttpProfile(container.partNumber, container.serialNumber, container.profile)
          l_profileScript.registerHttpFunction(container.profile)
        else
          CSK_LiveConnect.addMqttProfile(container.partNumber, container.serialNumber, container.profile)
          l_profileScript.startMqttPayloadSimulation(container.partNumber, container.serialNumber)
        end
      else
        print(l_status)
      end
    end
  else
    print("No profiles connected")
  end
end

-------------------------------------------------------------------------------------
-- Add a device / profile combination 
local function addProfile(partNumber, serialNumber, connectionType, profileName)
  local l_status, l_profileScript = handleProfileData(profileName, connectionType)
  if l_status == "OK" then
    if connectionType == "MQTT" then
      -- Create profile
      local l_profile = l_profileScript.createMqttProfile()

      -- Persist profile
      saveProfile(profileName, partNumber, serialNumber, connectionType, l_profile)

      -- Add profile
      CSK_LiveConnect.addMqttProfile(partNumber, serialNumber, l_profile)

      -- Start payload generation
      l_profileScript.startMqttPayloadSimulation(partNumber, serialNumber)
    else
      -- Create profile
      local l_profile = l_profileScript.createHttpProfile()

      -- Persist profile
      saveProfile(profileName, partNumber, serialNumber, connectionType, l_profile)

      -- Add profile
      CSK_LiveConnect.addHttpProfile(partNumber, serialNumber, l_profile)

      -- Register callback function
      l_profileScript.registerHttpFunction(l_profile)
    end
  end

  return l_status
end
Script.serveFunction('Test.addProfile', addProfile)

-------------------------------------------------------------------------------------
-- Get all connected profiles
local function getProfiles()
  -- Load container
  local l_containers = getProfilesFromContext()
  if l_containers ~= nil then
    local result = {}
    for _,container in pairs(l_containers) do
      table.insert(result, {profile=container.profile:getName(), sn=container.serialNumber, pn=container.partNumber})
    end

    return m_json.encode(result)
  else
    return "No profiles connected"
  end
end
Script.serveFunction('Test.getProfiles', getProfiles)

-------------------------------------------------------------------------------------
-- Delete all profiles
local function deleteAllProfiles()
  local l_httpProfiles = getProfilesFromContext()

  if l_httpProfiles ~= nil then
    for _,container in pairs(l_httpProfiles) do
      print(string.format("Remove peer device (PN:%s | SN:%s)", container.partNumber, container.serialNumber))
      CSK_LiveConnect.removePeerDevice(container.partNumber, container.serialNumber)
      if container.connectionType == "MQTT" then
        local l_status, l_profileScript = handleProfileData(container.profileName, container.connectionType)
        if l_status == "OK" then
          l_profileScript.stopMqttPayloadSimulation(container.partNumber, container.serialNumber)
        end
      end
    end
  end

  CSK_PersistentData.removeParameter(PARAMETER_NAME)
  CSK_PersistentData.saveData()

  -- Restart Client
  CSK_LiveConnect.removeAllProfiles()

  return "OK"
end
Script.serveFunction('Test.deleteAllProfiles', deleteAllProfiles)


-------------------------------------------------------------------------------------
-- Test event OnProfileAdded
local function profileAdded(name, profileType)
  print(string.format("%s profile added (%s)", profileType, name))
end
Script.register("CSK_LiveConnect.OnNewProfileAdded", profileAdded)

-------------------------------------------------------------------------------------
-- Start delay to ensude the LiveConnect client is intialized
local function main()
  -- Add DNS server to resolve the LiveConnect api url
  Ethernet.DNS.setNameservers("35.157.9.76")

  -- Load profiles from context
  loadProfiles()
end
--Script.register("Engine.OnStarted", main)
Script.register("CSK_LiveConnect.OnClientInitialized", main)
