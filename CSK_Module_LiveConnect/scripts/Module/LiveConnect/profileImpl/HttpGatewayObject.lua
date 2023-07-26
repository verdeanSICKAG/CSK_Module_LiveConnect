-------------------------------------------------------------------------------------
-- Variable declarations
local m_object = {}

-------------------------------------------------------------------------------------
-- Failed table lookups on the instances should fallback to the class table, to get methods
m_object.__index = m_object

-------------------------------------------------------------------------------------
-- Get reponse telegram for the "/gateway" endpoint
local function getEndpointGateway(self, request)
    local l_response = CSK_LiveConnect.Response.create()
    local l_header = CSK_LiveConnect.Header.create()
    CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
    CSK_LiveConnect.Header.setValue(l_header, "application/yaml")
  
    l_response:setHeaders({l_header})
    l_response:setStatusCode(200)
    l_response:setContent(File.open("resources/profiles/http_gateway.yaml", "rb"):read())

    return l_response
end

-------------------------------------------------------------------------------------
-- Get reponse telegram for the "/gateway/things-connected" endpoint
local function getEndpointThingsConnected(self, request)
    local l_response = CSK_LiveConnect.Response.create()
    local l_header = CSK_LiveConnect.Header.create()
    CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
    CSK_LiveConnect.Header.setValue(l_header, "application/json")

    l_response:setHeaders({l_header})
    l_response:setStatusCode(200)
    l_response:setContent("{}")

    return l_response
end

-------------------------------------------------------------------------------------
-- Create profile object
function m_object.create(baseUrl)
  local self = setmetatable({}, m_object)
  self.endpoints = {}
  self.baseUrl = baseUrl
  self.serviceLocation = "gateway"

  local l_profile = CSK_LiveConnect.HttpProfile.create()
  CSK_LiveConnect.HttpProfile.setUuid(l_profile, "1ac82280-d650-44f0-b373-7bf15a582e51")
  CSK_LiveConnect.HttpProfile.setName(l_profile,"HTTP Gateway")
  CSK_LiveConnect.HttpProfile.setVersion(l_profile, "0.0.1.20190712170000A")
  CSK_LiveConnect.HttpProfile.setDescription(l_profile,"A gateway HTTP/REST profile.")
  CSK_LiveConnect.HttpProfile.setOpenAPISpecification(l_profile, File.open("resources/profiles/http_gateway.yaml", "rb"):read())
  CSK_LiveConnect.HttpProfile.setServiceLocation(l_profile, self.serviceLocation)

  self.profile = l_profile

  -- Add profile endpoints
  self:addEndpoint("gateway", self.baseUrl .. "/gateway", "GET", getEndpointGateway)
  self:addEndpoint("gatewayThingsConnected", self.baseUrl .. "/gateway/things-connected", "GET", getEndpointThingsConnected)
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