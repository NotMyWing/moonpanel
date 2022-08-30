--[[
    dlx.lua

    Written by Soojin Nam. Public Domain.
    Algorithm 7.2.2.1C (Exact covering with colors).
    The original code was based on Knuth's Algorithm C.

    Moonpanel donor: commit 380ea4a94556083b593565e08b52d1da48f4495e.
    This namespaced shared adaptation retains the dancing-links core while
    accepting structured rows, removing globals/debug output, making MRV ties
    stable, and reporting deterministic work to a cooperative coroutine
    budget. Moonpanel's positive polyomino problem uses primary items only.
]]

local DLX = {}

local function linkHorizontal(left, right)
    left.right = right
    right.left = left
end

local function appendVertical(column, node)
    node.column = column
    node.down = column
    node.up = column.up
    column.up.down = node
    column.up = node
    column.size = column.size + 1
end

local function cover(column)
    column.right.left = column.left
    column.left.right = column.right

    local row = column.down
    while row ~= column do
        local node = row.right
        while node ~= row do
            node.down.up = node.up
            node.up.down = node.down
            node.column.size = node.column.size - 1
            node = node.right
        end
        row = row.down
    end
end

local function uncover(column)
    local row = column.up
    while row ~= column do
        local node = row.left
        while node ~= row do
            node.column.size = node.column.size + 1
            node.down.up = node
            node.up.down = node
            node = node.left
        end
        row = row.up
    end

    column.right.left = column
    column.left.right = column
end

local function chooseColumn(root)
    local best
    local column = root.right
    while column ~= root do
        if not best or column.size < best.size or
                (column.size == best.size and column.order < best.order) then
            best = column
            if best.size == 0 then break end
        end
        column = column.right
    end
    return best
end

local function build(primaryItems, optionRows, checkpoint)
    local steps = 0
    local function spend()
        steps = steps + 1
        return not checkpoint or checkpoint(1) ~= false
    end
    local root = { id = "__root", order = 0 }
    root.left = root
    root.right = root

    local columns = {}
    for index, item in ipairs(primaryItems) do
        if not spend() then return nil, steps end
        assert(columns[item] == nil, "duplicate exact-cover item")
        local column = {
            id = item,
            order = index,
            size = 0,
        }
        column.up = column
        column.down = column
        linkHorizontal(root.left, column)
        linkHorizontal(column, root)
        columns[item] = column
    end

    for rowIndex, option in ipairs(optionRows) do
        local first
        local previous
        for _, item in ipairs(option.items) do
            if not spend() then return nil, steps end
            local column = assert(columns[item], "unknown exact-cover item")
            local node = {
                rowIndex = rowIndex,
                rowId = option.id or rowIndex,
                payload = option.payload,
            }
            appendVertical(column, node)
            if not first then
                first = node
                node.left = node
                node.right = node
            else
                linkHorizontal(previous, node)
                linkHorizontal(node, first)
            end
            previous = node
        end
    end

    return root, steps
end

-- primaryItems and optionRows must already be in canonical order.  checkpoint
-- is called after each attempted option and returns false on complexity abort.
function DLX.Solve(primaryItems, optionRows, checkpoint)
    local root, steps = build(primaryItems, optionRows, checkpoint)
    if not root then return { status = "complexity", steps = steps } end
    local selected = {}
    local aborted = false

    local function search(depth)
        if root.right == root then return true end

        local column = chooseColumn(root)
        if not column or column.size == 0 then return false end
        cover(column)

        local row = column.down
        while row ~= column do
            steps = steps + 1
            if checkpoint and checkpoint(1) == false then
                aborted = true
                uncover(column)
                return false
            end

            selected[depth] = row
            local node = row.right
            while node ~= row do
                cover(node.column)
                node = node.right
            end

            if search(depth + 1) then
                uncover(column)
                return true
            end

            node = row.left
            while node ~= row do
                uncover(node.column)
                node = node.left
            end
            selected[depth] = nil
            if aborted then
                uncover(column)
                return false
            end
            row = row.down
        end

        uncover(column)
        return false
    end

    local solved = search(1)
    if aborted then
        return { status = "complexity", steps = steps }
    end
    if not solved then
        return { status = "unsatisfied", steps = steps }
    end

    local rows = {}
    for index = 1, #selected do
        local node = selected[index]
        rows[index] = {
            id = node.rowId,
            payload = node.payload,
        }
    end
    return {
        status = "solved",
        steps = steps,
        rows = rows,
    }
end

return DLX
