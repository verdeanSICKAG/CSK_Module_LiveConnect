-- External lib, licenced under MIT

local newdecoder = require 'utils/lunajson.Decoder'
local newencoder = require 'utils/lunajson.Encoder'
local sax = require 'utils/lunajson.Sax'
-- If you need multiple contexts of decoder and/or encoder,
-- you can require lunajson.decoder and/or lunajson.encoder directly.
return {
	decode = newdecoder(),
	encode = newencoder(),
	newparser = sax.newparser,
	newfileparser = sax.newfileparser,
}
