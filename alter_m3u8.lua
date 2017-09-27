-- @TODO: tag, md5, length for HEAD 
local str = require "resty.string"

function http_proxy(host, port, data)
    -- https://github.com/openresty/lua-nginx-module#ngxsockettcp
    local sock = ngx.socket.tcp()
    sock:settimeouts(30000, 10000, 2000) 
    local ok, err = sock:connect(host, port)
    if err then
        ngx.log(ngx.ERR, err)
        return nil, 502
    end
    local bytes, err = sock:send(data)
    if err then
        return nil, 500
    end
    local data, err, partial = sock:receive('*a')
        if err then
            return '1', partial
        else
            return '0', data
        end
end

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
         table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end


req_headers = ngx.req.get_headers()
--table.foreach(req_headers, function(k,v) ngx.print(k .. v) end)
host = req_headers["Host"]
backend = ngx.var.backend
backendPort = 80 

reqList = split(ngx.req.raw_header(), '\r\n')
sentData = ''

for k,v in ipairs(reqList) do
    if k == '' then
        break
    end
    if string.match(v, "Host") then
        reqList[k] = 'Host: ' .. backend
    end
end

sendData = table.concat(reqList, '\r\n')
sendData = sendData .. '\r\n'
ngx.log(ngx.INFO, sendData)
--ngx.exit(200)

code, data = http_proxy( backend, backendPort, sendData)
if code == nil then
    ngx.exit(data)
end
dataList = split(data, '\r\n\r\n')
table.foreach(dataList, function(k,v) ngx.log(ngx.INFO, k .. v) end)

headers = dataList[1]
body = dataList[2] or ''
ngx.log(ngx.INFO, headers .. body)
headersList = split(headers, '\r\n')
for k,v in ipairs(headersList) do
    key = split(v, ': ')[1]
    val = split(v, ': ')[2] or ''
    ngx.header[key] = val
end

-- alter
-- escapedBackend = 'hls01%.ott%.disp%.guttv%.cibntv%.net'
ngx.log(ngx.ERR, backend)
escapedBackend = string.gsub(backend, '%.', '%%.')
ngx.log(ngx.ERR, escapedBackend)
rep = string.gsub(body, escapedBackend, host)
-- header
-- ETag: "01CDEFA991990AB23C017A2A766E17F9"
-- Content-MD5: Ac3vqZGZCrI8AXoqdm4X+Q==
-- Content-Length: 20382
-- for Header
if rep ~= '' then
    ngx.header["Content-Length"] = string.len(rep)  
end
ngx.print(rep)
