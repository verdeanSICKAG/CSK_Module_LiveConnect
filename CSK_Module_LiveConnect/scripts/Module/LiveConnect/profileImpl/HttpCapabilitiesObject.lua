-------------------------------------------------------------------------------------
-- Variable declarations
local m_object = {}
local m_json = require("utils.Lunajson")

-------------------------------------------------------------------------------------
-- Failed table lookups on the instances should fallback to the class table, to get methods
m_object.__index = m_object

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
-- Get reponse telegram for the "/capabilities" endpoint
local function getEndpointCapabilities(self, request)
  local l_response = CSK_LiveConnect.Response.create()
  local l_header = CSK_LiveConnect.Header.create()
  CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
  CSK_LiveConnect.Header.setValue(l_header, "application/yaml")

  l_response:setHeaders({l_header})
  l_response:setStatusCode(200)
  l_response:setContent(File.open("resources/profiles/http_capabilities.yaml", "rb"):read())

  return l_response
end

-------------------------------------------------------------------------------------
-- Get reponse telegram for the "capabilities/profiles" endpoint
local function getEndpointProfiles(self, request)
  local l_response = CSK_LiveConnect.Response.create()
  local l_header = CSK_LiveConnect.Header.create()
  CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
  CSK_LiveConnect.Header.setValue(l_header, "application/json")

  local l_profileTable = {}

  for _, profile in pairs(self.profileList) do
    local l_profileInfo = {}
    l_profileInfo['id'] = CSK_LiveConnect.HttpProfile.getUuid(profile)
    l_profileInfo['name'] = CSK_LiveConnect.HttpProfile.getName(profile)
    l_profileInfo['description'] = CSK_LiveConnect.HttpProfile.getDescription(profile)
    l_profileInfo["version"] = CSK_LiveConnect.HttpProfile.getVersion(profile)
    l_profileInfo['serviceLocation'] = self.baseUrl .. "/" .. CSK_LiveConnect.HttpProfile.getServiceLocation(profile)

    ---@diagnostic disable-next-line: param-type-mismatch
    table.insert(l_profileTable, l_profileInfo)
  end

  l_response:setHeaders({l_header})
  l_response:setStatusCode(200)
  l_response:setContent(m_json.encode(l_profileTable))

  return l_response
end

-------------------------------------------------------------------------------------
-- Create profile object
function m_object.create(baseUrl)
  local self = setmetatable({}, m_object)
  self.endpoints = {}
  self.baseUrl = baseUrl
  self.serviceLocation = "capabilities"
  self.profileList = {}

  local l_profile = CSK_LiveConnect.HttpProfile.create()
  CSK_LiveConnect.HttpProfile.setUuid(l_profile, "2b292921-823e-4fde-a9e7-a556fe493ec1")
  CSK_LiveConnect.HttpProfile.setName(l_profile,"Capabilities")
  CSK_LiveConnect.HttpProfile.setVersion(l_profile, "0.1.3.20190201100000A")
  CSK_LiveConnect.HttpProfile.setDescription(l_profile,"The SICK Standard Capabilities HTTP/REST profile.")
  CSK_LiveConnect.HttpProfile.setOpenAPISpecification(l_profile, File.open("resources/profiles/http_capabilities.yaml", "rb"):read())
  CSK_LiveConnect.HttpProfile.setServiceLocation(l_profile, self.serviceLocation)

  self.profile = l_profile

  -- Add profile endpoints
  local l_id = createUuid()
  self:addEndpoint("capabilities" .. l_id, self.baseUrl .. "/capabilities", "GET", getEndpointCapabilities)
  self:addEndpoint("capabilitiesProfiles" .. l_id, self.baseUrl .. "/capabilities/profiles", "GET", getEndpointProfiles)

  return self
end

-------------------------------------------------------------------------------------
-- Add endpoints
function m_object.addEndpoint(self, name, serviceUrl, method, _function)
  -- Hand over "self" variable
  local callFunction = function(request)
      return _function(self, request)
    end
  local l_crownName = "CSK_LiveConnect. " .. name
  local l_endpoint = CSK_LiveConnect.HttpProfile.Endpoint.create()
  CSK_LiveConnect.HttpProfile.Endpoint.setMethod(l_endpoint, method)
  CSK_LiveConnect.HttpProfile.Endpoint.setURI(l_endpoint, serviceUrl)
  CSK_LiveConnect.HttpProfile.Endpoint.setHandlerFunction(l_endpoint, l_crownName)

  self.endpoints[serviceUrl] = l_endpoint
  Script.serveFunction(l_crownName, callFunction, "object:CSK_LiveConnect.Request", "object:CSK_LiveConnect.Response")
end

-------------------------------------------------------------------------------------
-- Get endpoints
function m_object.getEndpoints(self)
  return self.endpoints
end

-------------------------------------------------------------------------------------
-- Set profile list
function m_object.setProfileList(self, profileList)
  self.profileList = profileList
end

-------------------------------------------------------------------------------------
-- Set profile
function m_object.addProfile(self, profile)
  table.insert(self.profileList, profile)
end

-------------------------------------------------------------------------------------
-- Return local function to be used it in other scripts
return m_object