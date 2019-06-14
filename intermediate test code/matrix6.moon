systime = (timer and timer.systime) or os.clock
if true
    table_insert = table.insert
    rotate90 = (matrix) ->
        out = {}
        length = #matrix
        width = #matrix[1]
        
        for i = 1, length
            for j = 1, width
                out[j] or= {}
                out[j][length + 1 - i] or= {}
                out[j][length + 1 - i] = matrix[i][j]

        return out


    compareMatrices = (m1, m2) ->
        m1h = #m1
        m1w = #m1[1]
        m2h = #m2 
        m2w = #m2[1]
        if m1w ~= m2w or m1h ~= m2h
            return false

        for j = 1, m1h
            for i = 1, m1w
                v1 = (m1[j][i] ~= 0) and 1 or 0
                v2 = (m2[j][i] ~= 0) and 1 or 0
                if v1 ~= v2
                    return false
        
        return true

    printMatrix = (matrix) ->
        print "---"
        
        for j = 1, #matrix
            str = "["
            for i = 1, #matrix[1]
                str ..= matrix[j][i] or 0
                if i ~= #matrix[1]
                    str ..= ", "
            print str .. "]"

    copy = (m) ->
        new = {}
        h = #m
        w = #m[1]

        for j = 1, h
            new[j] = {}
            for i = 1, w
                new[j][i] = m[j][i]

        return new

    deduplicate = (m) ->
        newm = {}
        for j = 1, #m
            isDupe = false
            for i = 1, #newm
                if compareMatrices m[j], newm[i]
                    isDupe = true
                    break
            if not isDupe
                newm[#newm + 1] = m[j]
        return newm
    
    sort = (a, b) ->
        if a < b
            return a, b
        else
            return b, a

    overlap = (m1, m2, dstX, dstY) ->
        m1h = #m1
        m1w = #m1[1]
        m2h = #m2
        m2w = #m2[1]

        minx, ax = sort(1, dstX)
        miny, ay = sort(1, dstY)
        bx, maxx = sort(m1w, dstX + m2w - 1)
        by, maxy = sort(m1h, dstY + m2h - 1)

        is_m1_topmost = ay == 1
        is_m1_leftmost = ax == 1

        for y = 0, by - ay
            m1y = is_m1_topmost and (ay + y) or y + 1
            m2y = (not is_m1_topmost) and (ay + y) or y + 1
            for x = 0, bx - ax
                m1x = is_m1_leftmost and (ax + x) or x + 1
                m2x = (not is_m1_leftmost) and (ax + x) or x + 1
                
                m1v, m2v = nil, nil
                if m1[m1y]
                    m1v = m1[m1y][m1x]
                if m2[m2y]
                    m2v = m2[m2y][m2x]

                print m1v or -1, m2v or -1

        
        return false

    poly1 = {
        {1, 1, 1}
        {1, 1, 1}
        {1, 1, 1}
    }

    poly2 = {
        {1, 1, 1}
        {1, 1, 1}
        {1, 1, 1}
    }

    {poly1, poly2, 1, 1}
    {1, 1, 1, 0}
    {1, 2, 2, 1}
    {1, 2, 2, 1}
    {0, 1, 1, 1}

    print overlap poly1, poly2, 2, 2