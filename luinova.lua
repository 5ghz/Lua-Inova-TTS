#MIT License
#Author: pershin87@yandex.ru

#!/usr/bin/lua

local io = require("io")
local ltn12 = require("ltn12")
local https = require("ssl.https")
local sha = require("sha2")
local json = require("cjson")
require("hmac.sha2")
require("DataDumper")

--- eu-west-1: tts.eu-west-1.ivonacloud.com (EU, Dublin)
--- us-east-1: tts.us-east-1.ivonacloud.com (US East, N. Virginia)
--- us-west-2: tts.us-west-2.ivonacloud.com (US West, Oregon)
service = 'tts'
region = 'eu-west-1'
accessKey = 'GDNAJI223MMC74RGOC3A'
secretKey = '6ACiPZUTGkSylAv6960O1iaE+fS+VGznfHTCBHvS'
requestmethod = 'POST'
url = '/CreateSpeech'
contenttype = 'application/json'
date = os.date('!%Y%m%d')
time = os.date('!%H%M%S')
cryptomethod = 'AWS4-HMAC-SHA256'
inputtype='text/plain'
outcodec='MP3'
outsamplerate=22050
prate =  'medium'
pvolume = 'medium'
psentencebreak = 400
pparagraphbreak = 650
host = service .. '.' .. region  .. '.ivonacloud.com'

function dump(...)
  print(DataDumper(...), "\n---")
end

local function bintohex(s)
  return (s:gsub('(.)', function(c)
    return string.format('%02x', string.byte(c))
  end))
end 

function tts(voicelang,voicename,voicegender,text,filename)

  local datapayload = {
      Input = {
                 Data = text
      },
      OutputFormat = {
                 Codec = outcodec,
                 SampleRate = outsamplerate
      },
      Parameters = {
                 Rate = prate,
                 Volume = pvolume,
                 SentenceBreak = psentencebreak,
                 ParagraphBreak = pparagraphbreak
      },
      Voice = {
                 Name = voicename,
                 Language = voicelang,
                 Gender = voicegender
      }
  }
  local jsonpayload = json.encode(datapayload)
  local sha256json = sha.sha256hex(jsonpayload)
  local payload = requestmethod..'\n'..url..'\n'..'\n'..'content-type:'..contenttype..'\n'..'host:'..host..'\n'
  payload = payload..'x-amz-content-sha256:'..sha256json..'\n'
  payload = payload..'x-amz-date:'..date..'T'..time..'Z\n\n'
  payload = payload..'content-type;host;x-amz-content-sha256;x-amz-date\n'
  payload = payload..sha256json

  local stringtosign = cryptomethod..'\n'..date..'T'..time..'Z\n'..date..'/'..region..'/'..service..'/'
  stringtosign = stringtosign ..'aws4_request\n'..sha.sha256hex(payload)

  local datekey = hmac.sha256(date,'AWS4'..secretKey)
  local dateregionkey = hmac.sha256(region,datekey)
  local dateregionservicekey = hmac.sha256('tts',dateregionkey)
  local signingkey = hmac.sha256('aws4_request',dateregionservicekey)
  local signature = bintohex(hmac.sha256(stringtosign,signingkey))

-- Authorization: AWS4-HMAC-SHA256 Credential=12345/20130913/eu-west-1/tts/aws4_request,
  local authorization = cryptomethod .. ' Credential='..accessKey..'/'..date..'/'..region..'/'..service..'/'..'aws4_request,'
  authorization = authorization .. 'SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date,'
  authorization = authorization .. 'Signature='..signature
  local xFile = io.open(filename, "w")

  local itog,code,header,body=https.request{
      url = "https://tts.eu-west-1.ivonacloud.com/CreateSpeech",
      method = requestmethod,
      headers =
      {
          ["Content-Type"] = contenttype,
          ["Content-Length"] = string.len(jsonpayload),
          ["X-Amz-Date"] = date..'T'..time..'Z',
          ["Authorization"] = authorization,
          ["x-amz-content-sha256"] = sha256json
      },
      source = ltn12.source.string(jsonpayload),
      sink = ltn12.sink.file(xFile)
  }
end

tts('en-US','Salli','Female','Hello world!','test.mp3')