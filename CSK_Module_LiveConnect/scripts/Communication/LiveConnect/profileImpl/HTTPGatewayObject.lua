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
function m_object.create(baseURL)
  local self = setmetatable({}, m_object)
  self.endpoints = {}
  self.baseURL = baseURL
  self.serviceLocation = "gateway"

  local l_profile = CSK_LiveConnect.HTTPProfile.create()
  CSK_LiveConnect.HTTPProfile.setUUID(l_profile, "1ac82280-d650-44f0-b373-7bf15a582e51")
  CSK_LiveConnect.HTTPProfile.setName(l_profile,"HTTP Gateway")
  CSK_LiveConnect.HTTPProfile.setVersion(l_profile, "0.0.1.20190712170000A")
  CSK_LiveConnect.HTTPProfile.setDescription(l_profile,"A gateway HTTP/REST profile.")
  CSK_LiveConnect.HTTPProfile.setOpenAPISpecification(l_profile, File.open("resources/profiles/http_gateway.yaml", "rb"):read())
  CSK_LiveConnect.HTTPProfile.setServiceLocation(l_profile, self.serviceLocation)

  self.profile = l_profile

  -- Add profile endpoints
  self:addEndpoint("gateway", self.baseURL .. "/gateway", "GET", getEndpointGateway)
  self:addEndpoint("gatewayThingsConnected", self.baseURL .. "/gateway/things-connected", "GET", getEndpointThingsConnected)
  return self
end

-------------------------------------------------------------------------------------
-- Add endpoints
function m_object.addEndpoint(self, name, serviceURL, method, _function)
  -- Hand over "self" variable
  local callFunction = function(request)
      return _function(self, request)
    end
  local l_crownName = "CSK_LiveConnect. " .. name
  local l_endpoint = CSK_LiveConnect.HTTPProfile.Endpoint.create()
  CSK_LiveConnect.HTTPProfile.Endpoint.setMethod(l_endpoint, method)
  CSK_LiveConnect.HTTPProfile.Endpoint.setURI(l_endpoint, serviceURL)
  CSK_LiveConnect.HTTPProfile.Endpoint.setHandlerFunction(l_endpoint, l_crownName)

  self.endpoints[serviceURL] = l_endpoint
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