local format = require('prview.format')

local M = {}

function M.start(ctx)
    local generation, active = 0, nil
    local cache = {}
    local closed = false

    local function key(mr)
        return tostring(mr.project_id) .. ':' .. tostring(mr.iid)
    end

    local function cancel_active()
        generation = generation + 1
        if active and active.cancel then
            active.cancel()
        end
        active = nil
    end

    local function open_web(mr)
        if type(mr.web_url) ~= 'string' or mr.web_url:match('^https?://') == nil then
            ctx.notify('This merge request does not have a valid GitLab web URL.')
            return
        end
        ctx.open_url(mr.web_url)
    end

    local function load_diff(mr, callback)
        cancel_active()
        local cache_key = key(mr)
        local cached = cache[cache_key]
        if cached and not cached.err then
            callback(cached.content, cached.syntax, nil)
            return
        end

        local token = generation
        local request_completed = false
        local request
        request = ctx.transport.get_merge_request_diff(mr, function(diff, err)
            request_completed = true
            if closed or token ~= generation then
                return
            end
            active = nil
            if err then
                cache[cache_key] = { err = err }
                callback(nil, nil, err)
                return
            end

            local render_completed = false
            local render
            render = ctx.renderer.render(diff, function(content, syntax)
                render_completed = true
                if closed or token ~= generation then
                    return
                end
                active = nil
                cache[cache_key] = { content = content, syntax = syntax }
                callback(content, syntax, nil)
            end)
            if not render_completed then
                active = render
            end
        end)
        if not request_completed then
            active = request
        end
    end

    active = ctx.transport.list_merge_requests(function(items, err)
        if closed then
            return
        end
        active = nil
        if err then
            ctx.notify(err)
            return
        end
        if #items == 0 then
            ctx.notify('No open GitLab merge requests found.', vim.log.levels.INFO)
            return
        end
        ctx.picker.pick_merge_request(items, {
            format = format.merge_request,
            focus = function(mr, update)
                update('Loading merge request diff…', 'text')
                load_diff(mr, function(content, syntax, load_err)
                    update(load_err or content, load_err and 'text' or syntax)
                end)
            end,
            cancel = function()
                closed = true
                cancel_active()
            end,
            open_web = open_web,
        })
    end)

    return {
        cancel = function()
            closed = true
            cancel_active()
        end,
    }
end

return M
