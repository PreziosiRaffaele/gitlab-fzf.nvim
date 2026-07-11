local format = require('prview.format')

local M = {}

function M.start(ctx)
    local generation, active = 0, nil
    local cache = {}
    local closed = false

    local function cancel_active()
        generation = generation + 1
        if active and active.cancel then
            active.cancel()
        end
        active = nil
    end

    local function load(mr, retry, callback)
        local key = tostring(mr.project_id) .. ':' .. tostring(mr.iid)
        if cache[key] and not retry then
            callback(cache[key].items, cache[key].err)
            return
        end
        cancel_active()
        local token = generation
        active = ctx.transport.list_changed_files(mr, function(items, err)
            if closed or token ~= generation then
                return
            end
            active = nil
            cache[key] = { items = items, err = err }
            callback(items, err)
        end)
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
                update('Loading changed files…')
                load(mr, false, function(files, load_err)
                    update(load_err or format.file_summary(files))
                end)
            end,
            select = function(mr)
                load(
                    mr,
                    cache[tostring(mr.project_id) .. ':' .. tostring(mr.iid)]
                        and cache[tostring(mr.project_id) .. ':' .. tostring(mr.iid)].err ~= nil,
                    function(files, load_err)
                        if load_err then
                            ctx.notify(load_err)
                            return
                        end
                        if #files == 0 then
                            ctx.notify('This merge request has no changed files.', vim.log.levels.INFO)
                            return
                        end
                        ctx.picker.pick_changed_file(files, {
                            format = format.changed_file,
                            cancel = function() end,
                        })
                    end
                )
            end,
            cancel = function()
                closed = true
                cancel_active()
            end,
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
