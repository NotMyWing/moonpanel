
bit = require "bit" or require "bit32"

lshift = bit.lshift
band = bit.band
bor = bit.bor
bnot = bit.bnot
class Matrix
    new: (@w, @h) =>
        @rows = {}
        for j = 1, @h
            @rows[j] = 0

    compare: (other) =>
        if other.w ~= @w or other.h ~= @h
            return false

        for row = 1, @h
            if other.rows[row] ~= @rows[row]
                return false
        
        return true

    set: (i, j, value) =>
        mask = lshift 1, i
        if value ~= 0 and value ~= false
            @rows[j] = bor @rows[j], mask
        else
            @rows[j] = band @rows[j], bnot mask

    get: (i, j) =>
        return band(@rows[j], lshift 1, i) ~= 0

    print: () =>
        print "---"
        
        for j, row in pairs @rows
            str = "["
            for i = 1, @w
                str ..= (band(row, lshift 1, i) ~= 0) and 1 or 0
                if i ~= @w
                    str ..= ", "
            print str .. "]"

    fromNested: (nested) ->
        w = #nested[1]
        h = #nested
        m = Matrix w, h
        for j = 1, h
            for i = 1, w
                m\set i, j, nested[j][i]
        return m

    isZero: () =>
        for k, v in pairs @rows
            if v ~= 0
                return false
        return true

polys = {}

polys[1] = Matrix.fromNested {
    {1, 1, 1}
    {0, 1, 0}
} 

polys[2] = Matrix.fromNested {
    {1, 0, 1}
    {1, 1, 1}
}

negatives = {}

negatives[1] = Matrix.fromNested {
    {1, 1, 1}
    {1, 1, 1}
    {1, 1, 1}
}

