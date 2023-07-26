-------------------------------------------------------------------------------------
-- Variable declarations
local m_object = {}

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
-- Get reponse telegram for the "/api" endpoint
local function getEndpointApi(request)
    local l_response = CSK_LiveConnect.Response.create()
        local l_header = CSK_LiveConnect.Header.create()
    CSK_LiveConnect.Header.setKey(l_header, "Content-Type")
    CSK_LiveConnect.Header.setValue(l_header, "application/yaml")

    l_response:setHeaders({l_header})
    l_response:setStatusCode(200)
    l_response:setContent("") -- No profile available

    return l_response
end

-------------------------------------------------------------------------------------
-- Create profile object
function m_object.create(baseUrl)
  local self = setmetatable({}, m_object)
  self.endpoints = {}
  self.baseUrl = baseUrl
  self.serviceLocation = "api"

  local l_profile = CSK_LiveConnect.HttpProfile.create()
  CSK_LiveConnect.HttpProfile.setUuid(l_profile, "6de815fe-48e1-46b4-8d66-32f3606a4527")
  CSK_LiveConnect.HttpProfile.setName(l_profile,"HTTP/REST Device")
  CSK_LiveConnect.HttpProfile.setVersion(l_profile, "0.1.3.20190201100000A")
  CSK_LiveConnect.HttpProfile.setDescription(l_profile,"The SICK Standard HTTP Device HTTP/REST profile.")
  CSK_LiveConnect.HttpProfile.setServiceLocation(l_profile, self.serviceLocation)

  self.profile = l_profile

  -- Add profile endpoints
  local l_id = createUuid()
  self:addEndpoint("api" ..l_id, self.baseUrl .. "/api", "GET", getEndpointApi)

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