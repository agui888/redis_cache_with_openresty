local str = require "resty.string"
local req_args = ngx.req.get_uri_args()

function get_res(uri,req_args)
	-- rewrite to local/backend..uri
	backend_uri = "/backend" .. uri
	-- ngx.say(backend_uri)
	res = ngx.location.capture(backend_uri, { args = req_args })
	if res.status == 200 then
		--ngx.say("hello")
		--ngx.print(res.body)
		return "0",res.status,res.body
	else
		ngx.log(ngx.ERR,"capture ERR",res.status,'\n')
		-- ngx.status = 501
		-- ngx.print("capture ERR",'\n')
		return nil,res.status,res.body
	end
end	

local keystr = ngx.var.res 
local stu = ngx.null
local code = 500
local resu = ngx.null
ngx.header["Content-Type"]="application/json;charset=utf-8"

local redis = require "resty.redis";
local red, err = redis:new();
-- ngx.log(ngx.ERR, "start", "nool");
if not red then
    ngx.log(ngx.ERR, "failed to initialize redis library.", err)
	stu,code,resu = get_res(ngx.var.uri,req_args)
else
	--local ok, err = red:connect("127.0.0.1", 6379)
	local ok, err = red:connect("172.16.50.11", 6379)
	red:set_timeout(7000)
	if not ok then
		ngx.log(ngx.ERR, "failed to connect to redis.", err)
		ngx.log(ngx.ERR, "xxx",ngx.var.uri)
		stu,code,resu = get_res(ngx.var.uri,req_args)
	else
                -- add delete_api delete_redis = any
               	delete_redis = ngx.req.get_uri_args()["delete_redis"] or 0
               	-- ngx.log(ngx.ERR, "delete_", delete_redis)
		-- ngx.log(ngx.ERR,keystr)
		-- cache or get
              	if delete_redis == 0 then
			local cache, err = red:get(keystr)
			-- get_backend&& cache
			if cache == ngx.null then
				stu,code,resu = get_res(ngx.var.uri,req_args)
				if stu == nil then
					ngx.log(ngx.ERR,ngx.var.uri," :req backend failed: ",resu)
				else
					local ok, err = red:set(keystr, resu, "EX", ngx.var.timeout, "NX")
					if not ok then
						ngx.log(ngx.ERR,"redis:set err:", keystr, " ", resu)
					end
				end
			-- return cache
			else
				-- ngx.status = 304
				-- ngx.status = 200
				-- ngx.print(cache)
				code = 200
				resu = cache
			end
		-- delete action
		else
                    	local ok, err = red:del(keystr)
                   	-- false: false/nil
                    	local dcode = ok  and '0' or '-1'
                    	local msg = ok and 'succ' or err
                    	ngx.log(ngx.ERR, "delete", keystr, ":", ok, err)
                    	code = 200
          	       	resu = "{\"code\":" ..dcode.. ",\"msg\": \"" .. keystr .. ':'.. msg .. "\"}"
		end
		red:close()
	end
end
ngx.status=code
ngx.print(resu)
