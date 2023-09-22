-------------------------------------------------------------------------------------
-- Variable declarations
local m_object = {}

-------------------------------------------------------------------------------------
-- Failed table lookups on the instances should fallback to the class table, to get methods
m_object.__index = m_object

-------------------------------------------------------------------------------------
-- Get a generated UUID
local function createUUID()
  local l_template ='xxxxxxxx'
  local l_uuid =  string.gsub(l_template, '[xy]', function (c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)

  return l_uuid
end

-------------------------------------------------------------------------------------
-- Get reponse telegram for the main endpoint, which provides the profile
---comment
local function getEndpointProfile(self, request)
  local l_response = CSK_LiveConnect.Response.create()
  local l_header = CSK_LiveConnect.Header.create()
  CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
  CSK_LiveConnect.Header.setValue(l_header, "application/yaml")

  l_response:setHeaders({l_header})
  l_response:setStatusCode(200)
  l_response:setContent(self.profile:getOpenAPISpecification())

  return l_response
end

-------------------------------------------------------------------------------------
-- Create profile object
function m_object.create(baseURL, profile)
  local self = setmetatable({}, m_object)
  self.endpoints = {}
  self.baseURL = baseURL
  self.profile = profile

  -- Add openAPI profile endpoints
  local l_id = createUUID()
  local l_serviceURL = self.baseURL .. "/" .. self.profile:getServiceLocation()
  self:addEndpoint("openapi" .. l_id, l_serviceURL, "GET", getEndpointProfile)

  -- Add application related profiles
  for _, endpoint in pairs(self.profile:getEndpoints()) do
    self.endpoints[l_serviceURL .. "/" .. endpoint:getURI()] = endpoint
  end

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