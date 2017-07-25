local resty_sha1 = require "resty.sha1"
local str = require "resty.string"
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

local sha1 = resty_sha1:new()
local req_args = ngx.req.get_uri_args()

local keystr=nil
local list= split(ngx.arg[1],',')
for k,v in ipairs(list) do
    keystr=tostring(keystr) .."|".. req_args[v]
end
return keystr
