if SERVER
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
                if m1[j][i] ~= m2[j][i]
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

    ipsTraverse = (i, j, w, h, m, memo) ->
        memo[j] or= {}
        memo[j][i] = true
        memo.count += 1
        toTraverse = {
            { i - 1, j }
            { i, j - 1 }
            { i + 1, j }
            { i, j + 1 }
        }

        for k, point in pairs toTraverse
            x, y = point[1], point[2]
            if x >= 1 and x <= w and
                y >= 1 and y <= h and
                not (memo[y] and memo[y][x]) and m[y][x] == 1

                ipsTraverse x, y, w, h, m, memo

    isPathSeamless = (m) ->
        mh = #m
        mw = #m[1]

        numOnes = 0
        sx, sy = nil, nil
        for j = 1, mh
            for i = 1, mw
                if m[j][i] == 1
                    if not sx
                        sx = i
                        sy = i
                    numOnes += 1

        if numOnes == 0
            return false

        memo = { count: 0 }
        ipsTraverse sx, sy, mw, mh, m, memo

        return memo.count == numOnes

    pad = (m, addw, addh) ->
        h = #m
        w = #m[1]

        for j = 1, math.abs addh
            row = {}
            for i = 1, w + (math.abs addw)
                row[i] = 0
            if addh < 0
                table.insert m, 1, row
            else
                table.insert m, row

        low = (addh < 0) and ((math.abs addh) + 1) or 1
        high = (addh < 0) and (h + (math.abs addh)) or h
        for j = low, high
            for i = 1, (math.abs addw)
                if addw > 0
                    table.insert m[j], 0
                else  
                    table.insert m[j], 1, 0    

    copy = (m) ->
        new = {}
        h = #m
        w = #m[1]

        for j = 1, h
            new[j] = {}
            for i = 1, w
                new[j][i] = m[j][i]

        return new

    overlay = (m1, m2, dstX, dstY, srcX, srcY, desiredW = nil, desiredH = nil) ->
        m1h = #m1
        m1w = #m1[1]
        m2h = #m2
        m2w = #m2[1]

        -- Offset the second matrix, it's always easier to draw it
        -- from left to right, top to bottom.
        dX = (1 - srcX)
        dY = (1 - srcY)

        srcX += dX
        srcY += dY
        dstX += dX
        dstY += dY

        points = {
            { 1, 1 }   
            { 1, m1h }   
            { m1w, 1 }   
            { m1w, m1h }   

            { dstX, dstY }   
            { dstX, dstY + (m2h - 1) }   
            { dstX + (m2w - 1), dstY }   
            { dstX + (m2w - 1), dstY + (m2h - 1) }
        }

        minPoint = { points[1][1], points[1][2] }
        maxPoint = { points[1][1], points[1][2] }

        for k, v in pairs points
            minPoint[1] = (minPoint[1] > v[1]) and v[1] or minPoint[1]
            minPoint[2] = (minPoint[2] > v[2]) and v[2] or minPoint[2]
            maxPoint[1] = (maxPoint[1] < v[1]) and v[1] or maxPoint[1]
            maxPoint[2] = (maxPoint[2] < v[2]) and v[2] or maxPoint[2]

        newm = {}
        newmw = (maxPoint[1] - minPoint[1]) + 1
        newmh = (maxPoint[2] - minPoint[2]) + 1

        if desiredW ~= nil and newmw ~= desiredW
            return false

        if desiredH ~= nil and newmh ~= desiredH
            return false

        offsetX = 1 - minPoint[1]
        offsetY = 1 - minPoint[2]

        for j = 1, newmh
            newm[j] = {}
            m1y = (j - offsetY)
            m2y = m1y - (dstY - 1)
            for i = 1, newmw
                m1x = (i - offsetX)
                m2x = m1x - (dstX - 1)

                m1v = 0
                m2v = 0
                if m1x >= 1 and m1x <= m1w and m1y >= 1 and m1y <= m1h
                    m1v = m1[m1y][m1x] or 0            

                if m2x >= 1 and m2x <= m2w and m2y >= 1 and m2y <= m2h
                    m2v = m2[m2y][m2x] or 0
                
                if m1v == 1 and m2v == 1
                    return false

                newm[j][i] = ((m1v ~= 0) and m1v) or ((m2v ~= 0) and m2v) or 0
        
        return newm

    permute = (m, n, output) ->
        if n == 0 then
            permutations = {}
            for k, v in pairs m
                table.insert permutations, v
            table.insert output, permutations
        else
            for i = 1, n do
                m[i], m[n] = m[n], m[i]
                permute m, n - 1, output
                m[i], m[n] = m[n], m[i]

    combinations = (a, b, desiredW, desiredH) ->
        combs = {}

        originalA = a
        a = copy a

        -- Step zero: pad A from both sides
        for j = 1, #a
            table.insert a[j], 1, 0
            table.insert a[j], 0

        for j = 1, 2
            line = {}
            for i = 1, #a[1]
                line[i] = 0

            if j == 1
                table.insert a, line
            else
                table.insert a, 1, line
        
        -- Modify A before we go
        for j = 1, #a
            for i = 1, #a[1]
                if a[j][i] == 0
                    toCheck = {
                        { -1, 0 }
                        { 0, -1 }
                        { 1, 0 }
                        { 0, 1 }
                    }

                    valid = false
                    for k, v in pairs toCheck
                        x = i + v[1]
                        y = j + v[2]
                        if x >= 1 and x <= #a[1] and y >= 1 and y <= #a and a[y][x] == 1
                            valid = true
                            break

                    if not valid
                        a[j][i] = -1

        -- First step: collect all 0s from A
        zeroes = {}
        for j = 1, #a
            for i = 1, #a[1]
                if a[j][i] == 0
                    table.insert zeroes, { x: i - 1, y: j - 1 }
        
        -- Second step: collect all 1s from B
        ones = {}
        for j = 1, #b
            for i = 1, #b[1]
                if b[j][i] == 1
                    table.insert ones, { x: i, y: j }

        for _, one in pairs ones
            for _, zero in pairs zeroes
                o = overlay originalA, b, zero.x, zero.y, one.x, one.y, desiredW, desiredH
                if o
                    table.insert combs, o
        return combs

    polyos = {}
    permute {polyo1, polyo2}, 2, polyos

    polyo1 = {
        {1, 1}
        {0, 1}
    }

    polyo2 = {
        {1, 1, 1}
    }

    area = {
        { 1, 1, 0, 0 }
        { 0, 1, 0, 0 }
        { 0, 1, 1, 1 }
    }

    combs = (combinations polyo1, polyo2, 4, 3)

    solved = false
    for k, v in pairs combs
        if compareMatrices v, area
            print "Solution found"
            solved = true
            break
    if not solved
        print "Solution not found"