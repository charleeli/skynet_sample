local snax = require "snax"
local Lock = require 'lock'
local TimerMgr = require 'timer_mgr'
local Bson   = require 'bson'
local Env = require 'env'
local Role = require 'cls.role'
local td = require "td"

local M = {}

M.load_role_lock = Lock()
--[[
function M.reset_timer()
    if Env.timer_mgr then
        Env.timer_mgr:stop()
    end
    Env.timer_mgr = TimerMgr(10)
end
--]]
function M._load_role(role_td)
    local role = Role(role_td)
    Env.role = role
    role:init_apis()
 
    if Env.timer_mgr then
        Env.timer_mgr:stop()
    end

    Env.timer_mgr = TimerMgr(10)

    Env.timer_mgr:add_timer(60, function()
        role:save_db()
    end)
    
    Env.timer_mgr:add_timer(20, function()
        role:check_cron_update()
    end)
    
    Env.timer_mgr:add_timer(180, function()
        role:lock_session('update_mailbox')
    end)

    Env.timer_mgr:start()

    collectgarbage("collect")
    return role
end

function M.load_role()
    return M.load_role_lock:lock_func(function()
        assert(Env.uid)
        Env.account = tostring(Env.uid) --TODO:暂时第三方账号即为游戏服账号
        
        if not Env.role then
            local gamedb_snax = snax.uniqueservice("gamedb_snax")

            local raw_json_text = gamedb_snax.req.get(Env.account)

            local role_td
            if not raw_json_text then
                role_td = M.create_role("charleeli", 1)
            else
                role_td =  td.LoadFromJSON('Role',raw_json_text)
                M._load_role(role_td)
                Env.role:online()
            end
        end
        
        LOG_INFO(
            'load role<%s|%s|%s>',
            Env.account,Env.role:get_uid(), Env.role:get_uuid()
        )
       
        return Env.role:gen_proto()
    end)
end

function M.create_role(name, gender)
    local role = td.CreateObject('Role')
    local _,new_uuid = Bson.type(Bson.objectid())
    
    role.uid = Env.uid
    role.account = Env.account
    role.uuid = new_uuid
    
    role.base.uid = Env.uid
    role.base.name = name or 'anonym'
    role.base.gender = gender or 1
    role.base.exp = 0
    role.base.level = 1
    role.base.vip = 0

    local gamedb_snax = snax.uniqueservice("gamedb_snax")

    local ret = gamedb_snax.req.set(Env.account,td.DumpToJSON('Role', role))

    if not ret then
        LOG_ERROR('ac: <%s> create fail', Env.account)

        return {errcode = -2}

    end

    LOG_INFO(
        "create_role, uid<%s>,account<%s>, uuid<%s>, name<%s>, gender<%s>",
        role.uid,role.account, role.uuid, role.base.name, role.base.gender
    )

    local self = M._load_role(role)
    self:online()
    return {errcode = 0}
end

local triggers = {
}

return {apis = M, triggers = triggers}
