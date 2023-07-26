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
-- Get reponse telegram for the "/identification" endpoint
local function getEndpointIdentification(self, request)
    local l_response = CSK_LiveConnect.Response.create()
    local l_header = CSK_LiveConnect.Header.create()
    CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
    CSK_LiveConnect.Header.setValue(l_header, "application/yaml")
  
    l_response:setHeaders({l_header})
    l_response:setStatusCode(200)
    l_response:setContent(File.open("resources/profiles/http_identification.yaml", "rb"):read())

    return l_response
end

-------------------------------------------------------------------------------------
-- Get reponse telegram for the "/identification/identity" endpoint
local function getEndpointIdentity(self, request)
  local l_identity = {
    name = "",
    orderNumber = self.orderNumber,
    serialNumber = self.serialNumber,
    hardwareVersion = "",
    firmwareVersion = ""
  }

    local l_response = CSK_LiveConnect.Response.create()
    local l_header = CSK_LiveConnect.Header.create()
    CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
    CSK_LiveConnect.Header.setValue(l_header, "application/json")
  
    l_response:setHeaders({l_header})
    l_response:setStatusCode(200)
    l_response:setContent(m_json.encode(l_identity))

    return l_response
end

-------------------------------------------------------------------------------------
-- Get reponse telegram for the "/identification/applicationSpecificName" endpoint
local function getEndpointApplicationSpecificName(self, request)
    local l_response = CSK_LiveConnect.Response.create()
    l_response:setStatusCode(200)

    --TODO add content
    l_response:setContent('{"name": "' .. self.applicationSpecificName ..'"}')

    return l_response
end

-------------------------------------------------------------------------------------
-- Create profile object
function m_object.create(baseUrl, orderNumber, serialNumber)
  local self = setmetatable({}, m_object)
  self.endpoints = {}
  self.baseUrl = baseUrl
  self.orderNumber = orderNumber
  self.serialNumber = serialNumber
  self.serviceLocation = "identification"
  self.applicationSpecificName = "This is a SICK device" --TODO Make it chnageable via get/set + crown

  local l_profile = CSK_LiveConnect.HttpProfile.create()
  CSK_LiveConnect.HttpProfile.setUuid(l_profile, "84e38e5c-02a9-4e91-9dae-d2b6b19e51b6")
  CSK_LiveConnect.HttpProfile.setName(l_profile,"Device Identification")
  CSK_LiveConnect.HttpProfile.setVersion(l_profile, "0.1.4.20190510130000A")
  CSK_LiveConnect.HttpProfile.setDescription(l_profile,"The SICK Standard Device Identification HTTP/REST profile.")
  CSK_LiveConnect.HttpProfile.setOpenAPISpecification(l_profile, File.open("resources/profiles/http_identification.yaml", "rb"):read())
  CSK_LiveConnect.HttpProfile.setServiceLocation(l_profile, self.serviceLocation)

  self.profile = l_profile

  -- Add profile endpoints
  local l_id = createUuid()
  self:addEndpoint("identification" .. l_id, self.baseUrl .. "/identification", "GET", getEndpointIdentification)
  self:addEndpoint("identificationIdent" .. l_id, self.baseUrl .. "/identification/identity", "GET", getEndpointIdentity)
  self:addEndpoint("identificationAppName" .. l_id, self.baseUrl .. "/identification/applicationSpecificName", "GET", getEndpointApplicationSpecificName)
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
-- Return local function to be used it in other scripts
return m_object