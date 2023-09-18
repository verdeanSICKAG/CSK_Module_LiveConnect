---@diagnostic disable: undefined-global, param-type-mismatch, redundant-parameter
-------------------------------------------------------------------------------------
-- Variable declarations
local m_fifo = require("Communication.LiveConnect.utils.fifo.fifo")
local m_json = require("Communication.LiveConnect.utils.Lunajson")
local m_inspect = require("Communication.LiveConnect.utils.Inspect")
local m_base64 = require("Communication.LiveConnect.utils.base64.base64")
local m_iccClientObject = {}
local m_httpGatewayObject = require("Communication.LiveConnect.profileImpl.HTTPGatewayObject")
local m_httpRestObject = require("Communication.LiveConnect.profileImpl.HTTPRestObject")
local m_httpCapabilitiesObject = require("Communication.LiveConnect.profileImpl.HTTPCapabilitiesObject")

-------------------------------------------------------------------------------------
-- Constant values
local NAME_OF_MODULE = "CSK_LiveConnect"

-------------------------------------------------------------------------------------
-- Failed table lookups on the instances should fallback to the class table, to get methods
m_iccClientObject.__index = m_iccClientObject

-------------------------------------------------------------------------------------
-- Create UUID
local function uuid()
  local l_random = math.random
  local l_template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(l_template, '[xy]', function (c)
      local v = (c == 'x') and l_random(0, 0xf) or l_random(8, 0xb)
      return string.format('%x', v)
  end)
end

-------------------------------------------------------------------------------------
-- Get UTC time according to RFC 3339
local function getTimestamp()
  local l_day, l_month, l_year, l_hour, l_minute, l_second, l_millisecond = DateTime.getDateTimeValuesUTC()
  local l_ret = string.format("%04d-%02d-%02dT%02d:%02d:%02d.%03dZ",
    l_year, l_month, l_day, l_hour, l_minute, l_second, l_millisecond)

  return l_ret
end

-------------------------------------------------------------------------------------
-- Create profile object
function m_iccClientObject.create()
  local self = setmetatable({}, m_iccClientObject)
  self.iccApiKey = "YA9TcAoB9wFcc7huM8xmabAcw7ibrcteyqBki6p5"
  self.iccClientVersion = "3.0.0"
  self.iccClientName = "ICC Client (Lua)"
  self.standardInterfaceServer = "http://localhost:8080"
  self.caBundleSource = "resources/certs/cabundle.pem"
  self.caBundleFolder = "private/certs"
  self.caBundleFile = self.caBundleFolder .. "/cabundle.pem"
  self.mqttTopicBaseIdentification = "sick/device/identification"
  self.mqttTopicBaseCapabilities = "sick/capabilities/profiles"
  self.mqttTopicAsyncApi = "aai/asyncapi"
  self.softApprovalToken = "";

  self.enabled = false
  self.eventSubscribers = { OnConnectionStateChanged = {}}
  self.state = 'CHECK_PAIRING'
  self.discoveryResponse = nil
  self.isConnectionEstablished = false
  self.mqttDefaultCloudTopic = nil
  self.mqttDefaultDeviceTopic = nil
  self.mqttCloudTopics = {}
  self.iccBackendMqttClient = nil
  self.processTimer = Timer.create()
  self.deviceUuid = nil
  self.engineHasCryptoAPI = false
  self.phraseStore = nil
  self.phraseUse = nil
  self.peerDevices = {}
  self.connectedDelayTimer = Timer.create()
  self.forwardMqttMessageTimer = Timer.create()
  self.mqttMessageQueue = m_fifo()
  self.mqttSubscriptions = {}
  self.mqttDataImage = {} -- Stores all MQTT data telegrams
  self.httpProfilesGatewayDevice = {} -- HTTP profiles of the main device
  self.httpProfilesPeerDevice = {}
  self.httpEndpoints = {}
  self.profileGateway = m_httpGatewayObject.create(self.standardInterfaceServer)
  self.profileRest = m_httpRestObject.create(self.standardInterfaceServer)
  self.profileCapabilities = m_httpCapabilitiesObject.create(self.standardInterfaceServer)

  assert(File.mkdir("private/dev"),"Can't create directory in private folder")
  assert(File.mkdir("private/int"), "Can't create directory in private folder")
  assert(File.mkdir("private/prod"), "Can't create directory in private folder")

  -- Initialization
  self:setupCertificates()

  self:reinit()

  return self
end

-------------------------------------------------------------------------------------
-- First initialization / Re-initialize
function m_iccClientObject.reinit(self)
  if not self.enable then
    _G.logger:info(NAME_OF_MODULE .. ": Re-Initialize LiveConnect client")
  end

  if Cipher.RSA and Cipher.Key and Cipher.Certificate.SigningRequest then
    self.engineHasCryptoAPI = true
  end
  self.phraseStore = Hash.SHA256.calculateHex(liveConnect_Model.parameters.serialNumber .. Engine.getTypeName() .. "a91kgnasd95mkKGAlsfiSjGHasd")

  local l_handleProcessTimerOnExpired =
    function (data)
      self:process()
    end

  local l_handleForwardMqttMessageTimerOnExpired =
    function (data)
      self:handleForwardMqttMessageTimerOnExpired()
    end

  Timer.setPeriodic(self.processTimer, false)
  Timer.setExpirationTime(self.processTimer, liveConnect_Model.parameters.processIntervalMs)
  Timer.register(self.processTimer, "OnExpired", l_handleProcessTimerOnExpired)

  Timer.setExpirationTime(self.forwardMqttMessageTimer, liveConnect_Model.parameters.mqttMessageForwardingIntervalMs)
  Timer.register(self.forwardMqttMessageTimer,"OnExpired", l_handleForwardMqttMessageTimerOnExpired)
  Timer.setPeriodic(self.forwardMqttMessageTimer, true)

  if self.enable then
    _G.logger:info(NAME_OF_MODULE .. ": Restart LiveConnect client")
    self:disable()
    self:enable()
  end
end


-------------------------------------------------------------------------------------
-- Process main state machine
function m_iccClientObject.process(self)
  if self.enabled then
    if self.state == 'ERROR' then
      if self.iccBackendMqttClient ~= nil then
        Script.releaseObject(self.iccBackendMqttClient)
        self.iccBackendMqttClient = nil
      end
      self.discoveryResponse = nil
      self.isConnectionEstablished = false
      self.mqttDefaultCloudTopic = nil
      self.mqttDefaultDeviceTopic = nil
      self.mqttCloudTopics = {}
      self:setConnectionState('CHECK_PAIRING')
    end

    if self.state == 'CHECK_PAIRING' then
      if File.exists(self:getFileCert()) and File.exists(self:getFileCred()) and File.exists(self:getFileUuid()) then
        local l_file = File.open(self:getFileUuid(), "rb")
        if l_file ~= nil then
          self.deviceUuid = l_file:read()
          l_file:close()
        end
        local l_filePriv = File.open(self:getFileCred(), "rb")
        if l_filePriv ~= nil then
          local l_privBuf = l_filePriv:read()
          local l_head = string.sub(l_privBuf, 1, 37)
          if l_head == "-----BEGIN ENCRYPTED PRIVATE KEY-----" then
            self.phraseUse = self.phraseStore
          else
            self.phraseUse = nil
          end
          l_filePriv:close()
        end
        if nil == self.deviceUuid then
          _G.logger:warning(NAME_OF_MODULE .. ": Could not read device UUID")
        end
        self:setConnectionState('DISCONNECTED')
      end
    end

    if self.state == 'DISCONNECTED' then
      local l_discoveryResponse = self:runDiscovery()
      if nil ~= l_discoveryResponse then
        self.discoveryResponse = l_discoveryResponse
        self:setConnectionState('DISCOVERY_RESPONSE_RECEIVED')
      end
    end

    if self.state == 'DISCOVERY_RESPONSE_RECEIVED' then
      local l_connectSuccess = self:connectToICCBackend()
      if not l_connectSuccess then
        self:setConnectionState('ERROR')
      end
    end

    -- Start process timer
    Timer.start(self.processTimer)
  end
  CSK_LiveConnect.pageCalled()
end

-------------------------------------------------------------------------------------
-- Enable client
function m_iccClientObject.enable(self)
  _G.logger:info(NAME_OF_MODULE .. ": Enable LiveConnect Client")
  self.enabled = true
  self:process()
end

-------------------------------------------------------------------------------------
-- Disable client
function m_iccClientObject.disable(self)
  _G.logger:info(NAME_OF_MODULE .. ": Disable LiveConnect Client")
  Timer.stop(self.processTimer)
  if self.iccBackendMqttClient ~= nil then
    Script.releaseObject(self.iccBackendMqttClient)
    self.iccBackendMqttClient = nil
  end
  self.discoveryResponse = nil
  self.isConnectionEstablished = false
  self.mqttDefaultCloudTopic = nil
  self.mqttDefaultDeviceTopic = nil
  self.mqttCloudTopics = {}
  self:setConnectionState('CHECK_PAIRING')
  self.enabled = false
  self.deviceUuid = nil

  CSK_LiveConnect.pageCalled()
end

-------------------------------------------------------------------------------------
-- Reload all profiles
function m_iccClientObject.reloadProfiles(self)
  Timer.stop(self.processTimer)
  self.discoveryResponse = nil
  self.isConnectionEstablished = false
  self.mqttDefaultCloudTopic = nil
  self.mqttDefaultDeviceTopic = nil
  self.mqttCloudTopics = {}
  self:setConnectionState('DISCONNECTED')
  self.enabled = false

  -- Enabled it again
  self:enable()

end

-------------------------------------------------------------------------------------
-- Clear and reset all profiles and connected devices (instead of the paired gateway device)
function m_iccClientObject.removeAllProfiles(self)
  -- Disable client
  self:disable()

  self.peerDevices = {}
  self.mqttSubscriptions = {}
  self.mqttDataImage = {}
  self.httpProfilesGatewayDevice = {}
  self.httpProfilesPeerDevice = {}
  self.httpEndpoints = {}

  -- Clear message queue
  while self.mqttMessageQueue:length() > 0 do
    self.mqttMessageQueue:pop()
  end

  -- Add capabilities to the gateway device
  self:addMainCapabilities()

  -- Enabled it again
  self:enable()
end

-------------------------------------------------------------------------------------
-- Remove the given profile from a device
function m_iccClientObject.removeProfile(self, deviceUuid, profileUuid)
  Timer.stop(self.processTimer)
  self.discoveryResponse = nil
  self.isConnectionEstablished = false
  self.mqttDefaultCloudTopic = nil
  self.mqttDefaultDeviceTopic = nil
  self.mqttCloudTopics = {}
  self:setConnectionState('DISCONNECTED')
  self.enabled = false


  -- 1.) Remove profile from capabilities profile
  -- 2.) Re-add capabilities profile
  -- 3.) Remove profile subscriptions
  -- 4.) Remove profile endpoints
  -- 5.) Remove profile from Gateway/PeerDevice table


  self.mqttSubscriptions = {}
  self.httpProfilesPeerDevice = {}
  self.httpEndpoints = {}

  -- Enabled it again
  self:enable()
end

-------------------------------------------------------------------------------------
-- Handle received MQTT messages from the ICC backend
function m_iccClientObject.handleOnReceive(self, deviceTopic, data, qos, retain)
  if self.state == 'CONNECTED' then
    self:setConnectionState('EXECUTING_COMMAND')
    local l_cmd = m_json.decode(data)
    _G.logger:fine(NAME_OF_MODULE .. ": MQTT message receive: topic '" .. deviceTopic .. "' message '" .. m_inspect(l_cmd) .. "'")
    if 'COMMAND' == l_cmd['type'] then
      if l_cmd['command'] == "CONNECTION_ESTABLISHED" then
        self:handleConnectionEstablished(deviceTopic)
      elseif l_cmd['command'] == "PERFORM_HTTP_REQUEST" then
        self:handlePerformHTTPRequestCommand(l_cmd, deviceTopic)
      elseif l_cmd['command'] == 'DEVICE_IDENTITY' then
        self:handleDeviceIdentityCommand(l_cmd)
      elseif l_cmd['command'] == 'MQTT_SUBSCRIBE' then
        self:handleMqttSubscribeCommand(l_cmd)
      elseif l_cmd['command'] == 'MQTT_UNSUBSCRIBE' then
        _G.logger:warning(NAME_OF_MODULE .. ": Unhandled unsubscribe command received: " .. l_cmd['command'])
      else
        _G.logger:warning(NAME_OF_MODULE .. ": Received not implemented command: " .. l_cmd['command'])
      end
    elseif 'NOTIFY' == l_cmd['type'] then 
      _G.logger:info(NAME_OF_MODULE .. ": Received message \"" .. l_cmd['payload']['message'] .. "\"")
    end
  else
    _G.logger:warning(NAME_OF_MODULE .. ": Can't interpret data from cloud side")
  end
  if self.state == 'EXECUTING_COMMAND' then
    self:setConnectionState('CONNECTED')
  end
end

-------------------------------------------------------------------------------------
-- Establish MQTT connection to ICC backend
function m_iccClientObject.connectToICCBackend(self)
  _G.logger:info(NAME_OF_MODULE .. ": Connect to ICC backend")
  local l_mqttParams = self.discoveryResponse["mqtt"]

  if(self.iccBackendMqttClient ~= nil) then
    Script.releaseObject(self.iccBackendMqttClient)
    self.iccBackendMqttClient = nil
  end
  self.iccBackendMqttClient = MQTTClient.create()

  local l_onConnected = function () self:handleOnConnected() end
  local l_onDisconnected = function () self:handleOnDisconnected() end
  local l_onReceive = function (topic, data, qos, retain) self:handleOnReceive(topic, data, qos, retain) end
  self.iccBackendMqttClient:register("OnConnected", l_onConnected)
  self.iccBackendMqttClient:register("OnDisconnected", l_onDisconnected)
  self.iccBackendMqttClient:register("OnReceive", l_onReceive)

  self.iccBackendMqttClient:setTLSEnabled(true)
  self.iccBackendMqttClient:setCABundle(self.caBundleFile)
  self.iccBackendMqttClient:setClientCertificate(self:getFileCert(), self:getFileCred(), self.phraseUse)
  self.iccBackendMqttClient:setPeerVerification(true)
  self.iccBackendMqttClient:setIPAddress(l_mqttParams["host"])
  self.iccBackendMqttClient:setPort(l_mqttParams["port"])
  self.iccBackendMqttClient:setCleanSession(true)
  self.iccBackendMqttClient:setClientID(l_mqttParams["clientId"])
  self.iccBackendMqttClient:setKeepAliveInterval(math.ceil(liveConnect_Model.parameters.mqttKeepAliveIntervalMs / 1000.0))

  -- Stop process
  self.processTimer:stop()

  -- Connect to cloud broker
  _G.logger:fine(string.format("%s: MQTT connect timeout (%d ms)", NAME_OF_MODULE, liveConnect_Model.parameters.mqttConnectTimeoutMs))
  self.iccBackendMqttClient:connect(liveConnect_Model.parameters.mqttConnectTimeoutMs)

  -- Start process again
  self.processTimer:start()
  return self.iccBackendMqttClient:isConnected()
end

-------------------------------------------------------------------------------------
-- Handle "CONNECTION_ESTABLISHED" command from ICC backend
function m_iccClientObject.handleConnectionEstablished(self, deviceTopic)
  if self.mqttDefaultDeviceTopic == deviceTopic then
    self.isConnectionEstablished = true

    -- Now report connected peer devices
    for _, peerDevice in pairs(self.peerDevices) do
      self:registerPeerDevice(peerDevice)
    end
  else
    -- Peer devices don't need a token. They use the token of the gateway device
  end

  self.forwardMqttMessageTimer:start()
end

-------------------------------------------------------------------------------------
-- Handle "PERFORM_HTTP_REQUEST" command from ICC backend
function m_iccClientObject.handlePerformHTTPRequestCommand(self, command, deviceTopic)
  _G.logger:fine(NAME_OF_MODULE .. ": PERFORM_HTTP_REQUEST command received")

  local l_defaultResponseTopic = self.mqttCloudTopics[deviceTopic]
  if l_defaultResponseTopic == nil then
    l_defaultResponseTopic = self.mqttDefaultCloud
  end

  local l_response, l_responseTopic = self:createHTTPResponseCommand(command, defaultResponseTopic)
  local l_responseJSON = m_json.encode(l_response)
  _G.logger:fine(NAME_OF_MODULE .. ": PERFORM_HTTP_REQUEST response to " ..  l_responseTopic .. ": " .. m_inspect(l_response))

  MQTTClient.publish(self.iccBackendMqttClient, l_responseTopic, l_responseJSON, "QOS1")
end

-------------------------------------------------------------------------------------
-- Handle "DEVICE_IDENTITY" command from ICC backend
function m_iccClientObject.handleDeviceIdentityCommand(self, command)
  local l_serialNumber = command['payload']['serialNumber']
  local l_partNumber = command['payload']['partNumber']
  local l_deviceId = l_partNumber .. "_" .. l_serialNumber
  local l_peerDevice = self.peerDevices[l_deviceId]

  if l_peerDevice ~= nil then
    l_peerDevice.deviceUuid = command['payload']['deviceUuid']
    l_peerDevice.peerDeviceTopic = command['payload']['topics']['device']
    l_peerDevice.peerCloudTopic = command['payload']['topics']['cloud']


    self.mqttCloudTopics[l_peerDevice.peerDeviceTopic] = l_peerDevice.peerCloudTopic

    _G.logger:fine(string.format("%s: Subscribe to peer device topic (%s)", NAME_OF_MODULE, l_peerDevice.peerDeviceTopic))
    MQTTClient.subscribe(self.iccBackendMqttClient, l_peerDevice.peerDeviceTopic, "QOS1")

    self:publishConnectedCommand(l_peerDevice.baseUrl, l_peerDevice.peerCloudTopic)
  else
    _G.logger:warning(string.format("%s: Peer device (PN: %s and SN %s) is not known by the client", NAME_OF_MODULE, l_partNumber, l_serialNumber))
  end
  CSK_LiveConnect.pageCalled()
end

-------------------------------------------------------------------------------------
-- Handle "MQTT_SUBSCRIBE" command from the ICC backend
function m_iccClientObject.handleMqttSubscribeCommand(self, command)
  local l_topics = command['payload']['topic']

  -- Iterate over all subscriptions and store it to the table
  for _, topic in pairs(l_topics) do
    _G.logger:fine(NAME_OF_MODULE .. ": Added topic to subscription list (".. topic .. ")")
    self.mqttSubscriptions[topic] = topic
  end

  -- When a subscribe request is received, the corresponding response telegram
  -- is added to the MQTT message queue
  if self.mqttDataImage ~= nil then
    for _, message in pairs(self.mqttDataImage) do
      -- Check if a subscription is availabe for this message
      if self:isSubscripted(message.topic, l_topics) then
        _G.logger:fine(NAME_OF_MODULE .. ": Subscription available, push it to MQTT message queue (".. message.topic .. ")")
        self:addToMessageQueue(message)
      end
    end
  end
end

-------------------------------------------------------------------------------------
-- Perfom HTTP request and generate a HTTP response back via ICC channel 
function m_iccClientObject.createHTTPResponseCommand(self, command, responseTopic)
  local l_generatedUUID = uuid()
  local l_ret = {
    command = "ANNOUNCE_HTTP_RESPONSE",
    uuid = l_generatedUUID,
    payload = {}
  }
  l_ret["payload"]["referrer-uuid"] = command['uuid']
  if (nil ~= command['uuid']
    and nil ~= command['payload']
    and nil ~= command['payload']['request']['url']
    and nil ~= command['payload']['request']['method'])
  then
    if nil ~= command['payload']['replyTo'] then
      responseTopic = command['payload']['replyTo']
    end

    -- Prepare request
    local l_request = CSK_LiveConnect.Request.create()
    l_request:setHost(self.standardInterfaceServer)
    l_request:setURL(command['payload']['request']['url'])
    l_request:setMethod(command['payload']['request']['method'])
    if nil ~= command['payload']['request']['body'] then
      l_request:setContent(command['payload']['request']['body'])
    end
    if nil ~= command['payload']['request']['headers'] then
      local l_headers = {}
      for key, value in pairs(command['payload']['request']['headers']) do
        local l_valueToAdd = ""
        if value ~= nil then
          l_valueToAdd = value
        end
        local l_header = CSK_LiveConnect.Header.create()
        CSK_LiveConnect.Header.setKey(l_header, key)
        CSK_LiveConnect.Header.setValue(l_header, l_valueToAdd)
        table.insert(l_headers, l_header)
      end
      l_request:setHeaders(l_headers)
    end

    local l_response
    local l_success = false
    for endpointUrl,endpoint in pairs(self.httpEndpoints) do
       -- Check if the url includes parameters
      local l_requestUrl
      local l_paramPos = string.find(l_request:getURL(),"?")
      if l_paramPos == nil then
        l_requestUrl = l_request:getURL()
      else
        -- Remove params
        l_requestUrl = string.sub(l_request:getURL(), 1, l_paramPos - 1)
      end

      if endpointUrl == l_requestUrl then
        -- Check REST method
        if l_request:getMethod() == CSK_LiveConnect.HTTPProfile.Endpoint.getMethod(endpoint) then
          local l_handlerFunction = CSK_LiveConnect.HTTPProfile.Endpoint.getHandlerFunction(endpoint)
          l_success, l_response = Script.callFunction(l_handlerFunction, l_request)
          break
        else
          _G.logger:warning(NAME_OF_MODULE .. ": The method of the REST call does not match the method in the repository." )
        end
      end
    end

    -- Error: Endpoint not found in repository
    if not l_success then
      local l_message = "PERFORM_HTTP_REQUEST: HTTP endpoint not in repository (" .. l_request:getURL() .. ")"
      _G.logger:warning(NAME_OF_MODULE .. ": " .. l_message)
      l_ret['payload']['response'] = {
        error = "E_REQUEST_FAILED",
        message = l_message
      }
    else
      local l_headers = {}
      l_headers["Content-Length"] = #l_response:getContent()
      l_headers["Cache-Control"] = "no-cache, no-store"
      for _, header in pairs(l_response:getHeaders()) do
        l_headers[CSK_LiveConnect.Header.getKey(header)] = CSK_LiveConnect.Header.getValue(header)
      end

      l_ret['payload']['response'] = {
        statusCode = l_response:getStatusCode(),
        body = l_response:getContent(),
        headers = l_headers
      }
    end
  else
    _G.logger:warning(NAME_OF_MODULE .. ": PERFORM_HTTP_REQUEST command invalid")
    l_ret['payload']['response'] = {
      error = "E_INVALID_COMMAND",
      message = "Invalid command",
    }
  end
  return l_ret, responseTopic
end

-------------------------------------------------------------------------------------
-- Notify the ICC backend about a peer device
function m_iccClientObject.registerPeerDevice(self, peerDevice)
  local l_generatedUuid = uuid()

  local l_peerDeviceInfo = {
    uuid = l_generatedUuid,
    command = "DEVICE_DISCOVERED",
    type = "COMMAND",
    payload = {
      partNumber = peerDevice.partNumber,
      serialNumber = peerDevice.serialNumber,
      baseUrl = peerDevice.baseUrl
    }
  }

  _G.logger:fine(string.format("%s: Peer device discovered (%s)", NAME_OF_MODULE, m_inspect(l_peerDeviceInfo)))
  local l_deviceInfoJsonObject = m_json.encode(l_peerDeviceInfo)
  MQTTClient.publish(self.iccBackendMqttClient, self.mqttDefaultCloudTopic, l_deviceInfoJsonObject, "QOS1")
end

-------------------------------------------------------------------------------------
-- Add message to the MQTT message queue
function m_iccClientObject.addToMessageQueue(self, message)
  if (self.mqttMessageQueue:length() >= liveConnect_Model.parameters.mqttMessageQueueMaxLength) then
    -- Remove the oldest message in the queue if the queue is full
    _G.logger:warning(NAME_OF_MODULE .. ": Internal MQTT message queue is full (" .. liveConnect_Model.parameters.mqttMessageQueueMaxLength .. "), discard oldest message")
    self.mqttMessageQueue:pop()
  end

  self.mqttMessageQueue:push(message)
end

-------------------------------------------------------------------------------------
-- Check if the topic can be subscribed with one of the given subscriptions
function m_iccClientObject.isSubscripted(self, topic, subscriptions)
  local l_matchedWithSubscription = false
  local l_regexString

  -- Match MQTT wildcards
  if self.mqttSubscriptions ~= nil then
    for _,subscription in pairs(subscriptions) do
      l_regexString = string.gsub(subscription, "-", "%%-")
      l_regexString = string.gsub(l_regexString, "#", "%%.*")
      l_regexString = string.gsub(l_regexString, "+/", ".*")

      local l_match = string.match(topic, l_regexString)
      if l_match ~= nil then
        l_matchedWithSubscription = true
        break
      end
    end
  end

  return l_matchedWithSubscription
end

-------------------------------------------------------------------------------------
-- Add MQTT profile payload to the message queue
function m_iccClientObject.addMQTTTopic(self, topic, data, qos)
  if _qos ~= 'QOS0' then
    local l_message = {
      topic = topic,
      data = data,
      qos = qos,
      timestamp = getTimestamp() --DateTime.getUnixTime()
    }

    -- Store message
    self.mqttDataImage[topic] = l_message

    -- If the topic has already been subscribed, push the message into the
    -- message queue and send it to the cloud broker
    if self:isSubscripted(topic, self.mqttSubscriptions) then
      _G.logger:fine(NAME_OF_MODULE .. ": Add to MQTT message queue " .. topic)
      self:addToMessageQueue(l_message)
    end
  end
end

-------------------------------------------------------------------------------------
-- Set stage
function m_iccClientObject.setStage(self, stageEnum)
  local l_cloudSystem = nil
  if stageEnum == 0 then
    l_cloudSystem = "prod"
  elseif stageEnum == 1 then
    l_cloudSystem = "int"
  elseif stageEnum == 2 then
    l_cloudSystem = "dev"
  else
    assert(false, "Unknown cloud system, only PROD, INT and DEV available")
  end

  if (l_cloudSystem ~= liveConnect_Model.parameters.cloudSystem) then
    _G.logger:info(NAME_OF_MODULE .. ": Changing to cloud system " .. l_cloudSystem)
    local l_enableAgain = false
    if self.enabled then
      self:disable()
      l_enableAgain = true
    end

    liveConnect_Model.parameters.cloudSystem = l_cloudSystem
    if l_enableAgain then
      self:enable()
    end
  end
  CSK_LiveConnect.pageCalled()
end

-------------------------------------------------------------------------------------
-- Get ICC base url
function m_iccClientObject.getBaseURL(self)
  return "https://api." .. liveConnect_Model.parameters.cloudSystem .. ".sickag.cloud/icc"
end

-------------------------------------------------------------------------------------
-- Get discovery url
function m_iccClientObject.getDiscoveryUrl(self)
  return self:getBaseURL() .. "/discover"
end

-------------------------------------------------------------------------------------
-- Get soft approval url
function m_iccClientObject.getSoftapprovalUrl(self)
  return self:getBaseURL() .. "/device/softapproval"
end

-------------------------------------------------------------------------------------
-- Get certification directory
function m_iccClientObject.getCertDir(self)
  return "private/" .. liveConnect_Model.parameters.cloudSystem
end

-------------------------------------------------------------------------------------
-- Get certification file
function m_iccClientObject.getFileCert(self)
  return self:getCertDir() .. "/cert.pem"
end

-------------------------------------------------------------------------------------
-- Get credentails file
function m_iccClientObject.getFileCred(self)
  return self:getCertDir() .. "/cred.pem"
end

-------------------------------------------------------------------------------------
-- Get UUID file
function m_iccClientObject.getFileUuid(self)
  return self:getCertDir() .. "/uuid.txt"
end

-------------------------------------------------------------------------------------
-- Get status: Client is enabaled
function m_iccClientObject.isEnabled(self)
  return self.enabled
end

-------------------------------------------------------------------------------------
-- Get client connection state
function m_iccClientObject.getConnectionState(self)
  return self.state
end

-------------------------------------------------------------------------------------
-- Validate token
function m_iccClientObject.validateToken(self, token)
  local l_statusMessage = nil
  local l_success = false
  if nil == self.deviceUuid then
    local l_tokenValidationResponse = nil
    l_success, l_statusMessage, l_tokenValidationResponse = self:runTokenValidation(token)
    if l_success then
      l_success, l_statusMessage = self:processTokenValidationResponse(l_tokenValidationResponse)
    end
  else
    l_statusMessage = "Already paired"
  end

  return l_success, l_statusMessage
end

-------------------------------------------------------------------------------------
-- Remove pairing
function m_iccClientObject.removePairing(self)
  self:removeAllProfiles()
  local l_enableAgain = false
  if self.enabled then
    self:disable()
    l_enableAgain = true
  end

  File.del(self:getFileUuid())
  File.del(self:getFileCred())
  File.del(self:getFileCert())

  self.deviceUuid = nil
  self.softApprovalToken = ""

  if l_enableAgain then
    self:enable()
  end
  CSK_LiveConnect.pageCalled()
end

-------------------------------------------------------------------------------------
-- Register to an event
function m_iccClientObject.register(self, eventname, callback)
  table.insert(self.eventSubscribers[eventname], callback)
end

-------------------------------------------------------------------------------------
-- Update connection state
function m_iccClientObject.setConnectionState(self, newState)
  if self.state ~= newState then
    self.state = newState
    for _, callback in ipairs(self.eventSubscribers["OnConnectionStateChanged"]) do
      callback(newState)
    end
  end
end

-------------------------------------------------------------------------------------
-- Publish / forward data to the cloud MQTT broker
function m_iccClientObject.handleForwardMqttMessageTimerOnExpired(self)
  while self.mqttMessageQueue:length() > 0 and self.state ==  'CONNECTED' do
    local l_message = self.mqttMessageQueue:pop()
    local l_generatedUuid = uuid()
    local l_forwardMessage = {
      uuid = l_generatedUuid,
      command = "MQTT_MESSAGE",
      type = "COMMAND",
      payload = {
        topic = l_message.topic,
        ts = l_message.timestamp,
        data = nil
      }
    }

    -- Check if the message data is json, otherwise use base64 encoding
    local l_success, l_messageData = pcall(
      function ()
        return m_json.decode(l_message.data)
      end
    )

    if not l_success then
      -- Use Base64 encoding
      l_forwardMessage.payload.data = m_base64.encode(l_message.data)
      l_forwardMessage.payload['encoding'] = 'base64'
    else
      -- No encoding --> JSON
      l_forwardMessage.payload.data = l_messageData
    end

    _G.logger:fine(string.format("%s: Forward message to ICC backend (%s)", NAME_OF_MODULE, m_inspect(l_forwardMessage)))
    local l_jsonObject = m_json.encode(l_forwardMessage)
    if l_message.qos == "QOS2" then
      l_message.qos = "QOS1" -- AWS does not support QOS2
    end
    MQTTClient.publish(self.iccBackendMqttClient, self.mqttDefaultCloudTopic, l_jsonObject, l_message.qos)
  end
end

-------------------------------------------------------------------------------------
-- Create token validation payload
function m_iccClientObject.getTokenValidationPayload(self, token)
  local l_ret = {}
  l_ret['serialNumber'] = liveConnect_Model.parameters.serialNumber
  l_ret['partNumber'] = liveConnect_Model.parameters.partNumber
  l_ret['token'] = token

  if self.engineHasCryptoAPI then
    _G.logger:fine(NAME_OF_MODULE .. ": Generating key pair")
    local l_publicKey, l_privateKey = Cipher.RSA.generateKeyPair(2048)
    if l_publicKey == nil or l_privateKey == nil then
      l_ret = nil
      _G.logger:warning(NAME_OF_MODULE .. ": Generating key pair failed")
    else
      _G.logger:fine(NAME_OF_MODULE .. ": Generating key pair completed")
      
      local l_csr = Cipher.Certificate.SigningRequest.create()
      l_csr:setKeyPair(l_publicKey, l_privateKey)
      local l_csrBuf = l_csr:encode("PEM")
      if l_csrBuf == nil then
        l_ret = nil
        _G.logger:warning(NAME_OF_MODULE .. ": Generating certificate signing request failed")
      else
        local l_privateKeyBuf = l_privateKey:encode("PEM", self.phraseStore)
        local l_fprivKey = File.open(self:getFileCred(), "wb")
        if l_fprivKey == nil then
          l_ret = nil
          _G.logger:warning(NAME_OF_MODULE .. ": Storing private key failed")
        else
          if l_privateKeyBuf == nil then
            l_ret = nil
            _G.logger:warning(NAME_OF_MODULE .. ": Generating certificate signing request failed")
          else
            if not l_fprivKey:write(l_privateKeyBuf) then
              l_ret = nil
              _G.logger:warning(NAME_OF_MODULE .. ": Storing private key failed")
            else
              l_ret['csr'] = l_csrBuf
            end
          end
          l_fprivKey:close()
          Script.releaseObject(l_privateKey)
          ---@diagnostic disable-next-line: cast-local-type
          l_privateKey = nil
          Script.releaseObject(l_csr)
          ---@diagnostic disable-next-line: cast-local-type
          l_csr = nil
        end
      end
    end
  end

  return l_ret
end

-------------------------------------------------------------------------------------
-- Run token validation
function m_iccClientObject.runTokenValidation(self, token)
  _G.logger:info(NAME_OF_MODULE .. ": Run Token Validation (" .. token .. ")")
  local l_success = false
  local l_tokenResponse = nil
  local l_errorMessage = "Internal client error"
  local l_payload = self:getTokenValidationPayload(token)
  if l_payload ~= nil then
    _G.logger:fine(NAME_OF_MODULE .. ": Token validation payload: " .. m_inspect(l_payload))
    local l_payloadJSON = m_json.encode(l_payload)

    local l_client = HTTPClient.create()
    l_client:setCABundle(self.caBundleFile)
    l_client:setPeerVerification(true)
    l_client:setTimeout(liveConnect_Model.parameters.tokenTimeoutMs)

    local l_req = HTTPClient.Request.create()
    l_req:setMethod("POST")

    l_req:setURL(self:getSoftapprovalUrl())
    l_req:addHeader('X-Api-Key', self.iccApiKey)
    l_req:setContentBuffer(l_payloadJSON)
    l_req:setContentType("application/json")
    local response = l_client:execute(l_req)

    -- Check success
    l_success = response:getSuccess()
    if not l_success then
      local l_error = response:getError()
      local l_errorDetails = response:getErrorDetail()
      l_errorMessage = "Server not reachable: " .. l_error .. ". " .. l_errorDetails
    end

    if l_success then
      l_success = false
      if 200 == response:getStatusCode() then
        l_tokenResponse = m_json.decode(response:getContent())
        l_success = true
      elseif 403 == response:getStatusCode() then
        l_errorMessage = "Given token doesn't match to a device on the cloud side"
      elseif 406 == response:getStatusCode() then
        l_errorMessage = "Certification signing request did not carry a valid signature"
      elseif 409 == response:getStatusCode() then
        l_errorMessage = "Given partNumber "
        .. liveConnect_Model.parameters.partNumber .. " or serialNumber "
        .. liveConnect_Model.parameters.serialNumber .. " doesn't match to a device on the cloud side"
      elseif 500 == response:getStatusCode() then
        l_errorMessage = "Inconsistent data or service failure"
      else
        local l_errorObject = m_json.decode(response:getContent())
        l_errorMessage = l_errorObject['message']
      end
    end
  end

  -- Print message
  if not l_success and (l_errorMessage ~= nil) then
    _G.logger:warning(NAME_OF_MODULE .. ": " .. l_errorMessage)
  end

  return l_success, l_errorMessage, l_tokenResponse
end

-------------------------------------------------------------------------------------
-- Process softapproval token validation response
function m_iccClientObject.processTokenValidationResponse(self, tokenResponse)
  local l_success = false
  local l_errorMessage = nil
  if nil ~= tokenResponse['deviceUuid'] and nil ~= tokenResponse['certificate'] then
    local l_certificationFile = File.open(self:getFileCert(), "wb")
    if nil ~= l_certificationFile then
      l_success = true
      l_success = l_success and l_certificationFile:write(tokenResponse['certificate'])
    end
    local l_uuidFile  = File.open(self:getFileUuid(), "wb")
    l_success = l_success and l_uuidFile:write(tokenResponse['deviceUuid'])
    if not self.engineHasCryptoAPI and nil ~= tokenResponse['privateKey'] then
      local l_credentialsFile = File.open(self:getFileCred(), "wb")
      if nil ~= l_credentialsFile then
        l_success = l_success and l_credentialsFile:write(tokenResponse['privateKey'])
      else
        l_success = false
      end
    end
    if (l_success) then
      _G.logger:info(NAME_OF_MODULE .. ": Token approval response stored")
      self:setConnectionState('CHECK_PAIRING')
    else
      l_errorMessage = "Internal storage error"
    end
  else
    l_errorMessage = "Token validate response from server received but invalid " .. m_inspect(tokenResponse)
  end
  if nil ~= l_errorMessage then
    _G.logger:warning(NAME_OF_MODULE .. ": " .. l_errorMessage)
  end

  return l_success, l_errorMessage
end

-------------------------------------------------------------------------------------
-- Create ICC discovery request payload
function m_iccClientObject.getDiscoveryRequestPayload(self)
  local l_ret = nil
  local l_clientCertificationFile = File.open(self:getFileCert(), "rb")
  if l_clientCertificationFile == nil then
    _G.logger:severe(NAME_OF_MODULE .. ": Client certificate not found")
  else
    local l_clientCert = l_clientCertificationFile:read()
    l_ret = {
      certificate = l_clientCert
    }
  end

  return l_ret
end

-------------------------------------------------------------------------------------
-- Run ICC discovery
function m_iccClientObject.runDiscovery(self)
  _G.logger:info(NAME_OF_MODULE ..": Run device discovery, to connect the gateway device to the digital twin in the SICK AssetHub")
  local l_discoveryResponse = nil
  local l_payload = self:getDiscoveryRequestPayload()
  if l_payload == nil then
    self:setConnectionState('ERROR')
  else
    _G.logger:fine(NAME_OF_MODULE .. ": Discovery payload (" .. m_inspect(l_payload) ..")")
    local l_payloadJson = m_json.encode(l_payload)

    local l_httpClient = HTTPClient.create()
    l_httpClient:setCABundle(self.caBundleFile)
    l_httpClient:setPeerVerification(true)
    l_httpClient:setTimeout(liveConnect_Model.parameters.discoveryTimeoutMs)

    local l_req = HTTPClient.Request.create()
    l_req:setMethod("POST")
    l_req:setURL(self:getDiscoveryUrl())
    l_req:addHeader('X-Api-Key', self.iccApiKey)
    l_req:setContentBuffer(l_payloadJson)

    local l_response = l_httpClient:execute(l_req)

    -- Check success   
    local l_success = l_response:getSuccess()
    if not l_success then
      local l_error = l_response:getError()
      local l_errorDetails = l_response:getErrorDetail()
      _G.logger:warning(NAME_OF_MODULE .. ": No answer to discovery request (" .. l_error .. " Detail: " .. l_errorDetails .. ")")
    end

    if l_success then
      if (l_response:getStatusCode() ~= 200) then
        _G.logger:warning(NAME_OF_MODULE .. ": Discovery response (" .. l_response:getStatusCode() .. " payload " .. l_response:getContent() .. ")")
        self:setConnectionState('ERROR')
      else
        l_discoveryResponse = m_json.decode(l_response:getContent())
        _G.logger:fine(NAME_OF_MODULE .. ": Discovery response (" .. m_inspect(l_discoveryResponse) .. ")")
      end
    end
  end

  return l_discoveryResponse
end

-------------------------------------------------------------------------------------
-- Handle backend MQTT connection established
function m_iccClientObject.handleOnConnected(self)
  if nil ~= self.iccBackendMqttClient and nil ~= self.discoveryResponse then
    _G.logger:info(NAME_OF_MODULE .. ": MQTT connection to ICC backend established")
    self:setConnectionState('CONNECTED')

    local l_cloudTopic = self.discoveryResponse['mqtt']['topics']['cloud']
    local l_deviceTopic = self.discoveryResponse['mqtt']['topics']['device']
    self.mqttDefaultCloudTopic = l_cloudTopic
    self.mqttDefaultDeviceTopic = l_deviceTopic
    self.mqttCloudTopics[l_deviceTopic] = l_cloudTopic

    _G.logger:fine(NAME_OF_MODULE .. ": Subscribing to " .. l_deviceTopic)
    self.iccBackendMqttClient:subscribe(l_deviceTopic, "QOS1")

    -- Publish connected topic
    self:publishConnectedCommand(self.standardInterfaceServer, self.mqttDefaultCloudTopic)
  end
end

-------------------------------------------------------------------------------------
-- Handle backend MQTT connection loss
function m_iccClientObject.handleOnDisconnected(self)
  _G.logger:warning(NAME_OF_MODULE .. ": MQTT connection to ICC backend lost")
  self:setConnectionState('ERROR')

  self.forwardMqttMessageTimer:stop()
end

-------------------------------------------------------------------------------------
-- Publish "device connected" to the given topic (backend)
function m_iccClientObject.publishConnectedCommand(self, deviceBaseUrl, topic)
  local l_generatedUuid = uuid()
  local l_connectedCommand = {
    uuid = l_generatedUuid,
    command = "DEVICE_CONNECTED",
    type = "COMMAND",
    payload = {
      clientVersion = self.iccClientVersion,
      clientName = self.iccClientName,
      baseUrl = deviceBaseUrl
    }
  }
  local l_connectedCommadObject = m_json.encode(l_connectedCommand)
  MQTTClient.publish(self.iccBackendMqttClient, topic, l_connectedCommadObject , "QOS1")

  _G.logger:info(string.format(NAME_OF_MODULE .. ": Device is connected (topic: %s)", topic))
  _G.logger:fine(string.format(NAME_OF_MODULE .. ": - payload: %s)", m_inspect(l_connectedCommand)))
end

-------------------------------------------------------------------------------------
-- Publish "device disconnected" to the given topic (backend)
function m_iccClientObject.publishDisconnectedCommand(self, topic)
  if nil == self.iccBackendMqttClient then
    return
  end

  local l_generatedUuid = uuid()
  local l_disconnecedCommand = {
    uuid = l_generatedUuid,
    command = "DEVICE_DISCONNECTED",
    type = "COMMAND"
  }

  local l_disconnecedCommandObject = m_json.encode(l_disconnecedCommand)
  _G.logger:info(string.format(NAME_OF_MODULE .. ": Device is disconnected (topic: %s)", topic))
  _G.logger:fine(string.format(NAME_OF_MODULE .. ": Device is disconnected (topic: %s payload: %s)", topic, l_disconnecedCommandObject))
  MQTTClient.publish(self.iccBackendMqttClient, topic, l_disconnecedCommandObject, "QOS1")
end

-------------------------------------------------------------------------------------
-- Add a peer device which is connected to the gateway device 
-- Serial- and part number are used to identify a device
function m_iccClientObject.addPeerDevice(self, peerDevicePartNumber, peerDeviceSerialNumber, peerDeviceBaseUrl)
  local l_deviceId = peerDevicePartNumber .. "_" .. peerDeviceSerialNumber

  local l_peerDevice = {
    serialNumber = peerDeviceSerialNumber,
    partNumber = peerDevicePartNumber,
    baseUrl = peerDeviceBaseUrl,
    deviceUuid = nil,
    peerDeviceTopic = nil,
    peerCloudTopic = nil
  }

  if self.isConnectionEstablished then
    self:registerPeerDevice(l_peerDevice)
  end
  self.peerDevices[l_deviceId] = l_peerDevice

  CSK_LiveConnect.pageCalled()
end

-------------------------------------------------------------------------------------
-- Certification setup
function m_iccClientObject.setupCertificates(self)
  -- Copy root certificates to private a location within "private" resources folder
  -- Required to make them accessible for AppEngine
  if (false == File.exists(self.caBundleFolder)) then
    _G.logger:fine(NAME_OF_MODULE .. ": Creating folder for CA bundle (" .. self.caBundleFolder .. ")")
    assert(
      File.mkdir(self.caBundleFolder), ("Cannot create folder for CA bundle: " .. self.caBundleFolder)
    )
  end

  if (false == File.exists(self.caBundleFile)) then
    _G.logger:fine(NAME_OF_MODULE .. ": Copying CA bundle to appdata folder (" .. self.caBundleFolder .. ")")
    assert(
      File.copy(self.caBundleSource, self.caBundleFile), ("Cannot copy CA bundle to AppData folder: " .. self.caBundleFile)
    )
  end
end

-------------------------------------------------------------------------------------
-- Remove a peer device when it is offline or not longer connected
-- Serial- and part number are used to identify a device
function m_iccClientObject.removePeerDevice(self, partNumber, serialNumber)
  local l_deviceId = serialNumber .."_" .. partNumber

  local l_peerDevice = self.peerDevices[l_deviceId]
  if nil ~= l_peerDevice and nil ~= l_peerDevice.peerCloudTopic then
    self:publishDisconnectedCommand(l_peerDevice.peerCloudTopic)
    -- Delete peer device info
    self.peerDevices[l_deviceId] = nil
  end
end

-------------------------------------------------------------------------------------
-- Add http endpoint callback functions
function m_iccClientObject.addEndpoint(self, serviceLocation, endpoint)
  self.httpEndpoints[serviceLocation] = endpoint
end

-------------------------------------------------------------------------------------
-- Add main device profiles 
function m_iccClientObject.addHTTPProfileGatewayDevice(self, profile)
  table.insert(self.httpProfilesGatewayDevice, profile)
  self.profileCapabilities:setProfileList(self.httpProfilesGatewayDevice)
end

-------------------------------------------------------------------------------------
-- Add peer device profiles 
function m_iccClientObject.addHTTPProfilePeerDevice(self, profile, partNumber, serialNumber)
  local  l_index = partNumber .. "_" .. serialNumber
  if self.httpProfilesPeerDevice[l_index] == nil then
    self.httpProfilesPeerDevice[l_index] = {}
  end
  table.insert(self.httpProfilesPeerDevice[l_index], profile)
end

-------------------------------------------------------------------------------------
-- Add standard profile endpoints to the edge device
function m_iccClientObject.addMainCapabilities(self)
  --for serviceLocation, endpoint in pairs(self.profileGateway:getEndpoints()) do
  --  self.httpEndpoints[serviceLocation] = endpoint
  --end
  --self:addHTTPProfileGatewayDevice(self.profileGateway.profile)

  for serviceLocation, endpoint in pairs(self.profileRest:getEndpoints()) do
    self.httpEndpoints[serviceLocation] = endpoint
  end
  self:addHTTPProfileGatewayDevice(self.profileRest.profile)

  for serviceLocation, endpoint in pairs(self.profileCapabilities:getEndpoints()) do
    self.httpEndpoints[serviceLocation] = endpoint
  end
  self:addHTTPProfileGatewayDevice(self.profileCapabilities.profile)
end

-------------------------------------------------------------------------------------
-- Return local function to be used it in other scripts
return m_iccClientObject