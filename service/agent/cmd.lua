local skynet = require "skynet"
local notify = require 'notify'
local session_lock = require 'session_lock'
local date = require 'date'
local env = require 'env'

local M = {}

function M.start(e)
    env.uid = e.uid
    env.zinc_client = e.zinc_client

    if not e.uid then
        LOG_ERROR("msgagent start fail, no uid")
        return false
    end

    env.session_lock = session_lock()

    LOG_INFO('msgagent start, uid<%s>', e.uid)
    return true
end

-- 0-成功下线 1-下线失败 2-已经下线
local alread_close = false
function M.close()
    local ok, msg = pcall(function()
        if alread_close then
            return 2
        end

        skynet.fork(function()
            local ts = date.second()
            while true do
                local now = date.second()
                if now - ts > 300 then
                    LOG_ERROR("msgagent close failed in 5 mins")
                    if env.role then
                        env.role:save_db()
                    end

                    LOG_ERROR("agent force offline!")
                    break
                end
                skynet.sleep(5*100)
            end
        end)
        alread_close = true

        if env.role then
            if not env.role:offline() then
                return 1
            end
        end

        return 0
    end)

    return ok
end


function M.query_proto_info()
    skynet.retpack(env.role:gen_proto())
end

return M
