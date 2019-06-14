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
            table.insert newm, m[j]
    return newm

overlayTimesCalled = 0
overlay = (m1, m2, dstX, dstY, srcX, srcY) ->
    overlayTimesCalled += 1
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

    for i = 1, #points
        point = points[i]
        if (minPoint[1] < point[1])
            point[1] = minPoint[1]
        if (minPoint[2] < point[2])
            point[2] = minPoint[2]
        if (maxPoint[1] > point[1])
            point[1] = minPoint[1]
        if (maxPoint[2] > point[2])
            point[2] = minPoint[2]

    newm = {}
    newmw = (maxPoint[1] - minPoint[1]) + 1
    newmh = (maxPoint[2] - minPoint[2]) + 1

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
    start = os.clock!

    firstRotations = { copy a }
    secondRotations = { copy b }

    if a.rot
        for i = 2, 4
            rotation = rotate90 firstRotations[i - 1]
            shouldAdd = true
            for j = 1, #firstRotations
                if compareMatrices rotation, firstRotations[j]
                    shouldAdd = false
                    break
            if shouldAdd
                table.insert firstRotations, rotation

    if b.rot
        for i = 2, 4
            rotation = rotate90 secondRotations[i - 1]
            shouldAdd = true
            for j = 1, #secondRotations
                if compareMatrices rotation, secondRotations[j]
                    shouldAdd = false
                    break
            if shouldAdd
                table.insert secondRotations, rotation
            
    for _, first in pairs firstRotations
        _first = copy first
        -- Step zero: pad A from both sides
        for j = 1, #first
            table.insert first[j], 1, 0
            table.insert first[j], 0

        for j = 1, 2
            line = {}
            for i = 1, #first[1]
                line[i] = 0

            if j == 1
                table.insert first, line
            else
                table.insert first, 1, line
        
        -- Modify A before we go
        for j = 1, #first
            for i = 1, #first[1]
                if first[j][i] == 0
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
                        if x >= 1 and x <= #first[1] and y >= 1 and y <= #first and first[y][x] == 1
                            valid = true
                            break

                    if not valid
                        first[j][i] = -1

        -- First step: collect all 0s from A
        zeroes = {}
        for j = 1, #first
            for i = 1, #first[1]
                if first[j][i] == 0
                    table.insert zeroes, { x: i - 1, y: j - 1 }

        for _, second in pairs secondRotations               
            -- Second step: collect all 1s from B
            ones = {}
            for j = 1, #second
                for i = 1, #second[1]
                    if second[j][i] == 1
                        table.insert ones, { x: i, y: j }

            for j = 1, #zeroes
                zero = zeroes[j]
                for i = 1, #ones
                    one = ones[i]
                    o = overlay _first, second, zero.x, zero.y, one.x, one.y, desiredW, desiredH
                    if o
                        table.insert combs, o

    --print "Combinations took #{os.clock! - start} sec."
    return combs

iPolyos = {
    {
        {1, 1, 1}
        {0, 0, 1}
    }
    {
        {1, 1}
        {1, 1}
    }
    {
        {1, 0}
        {1, 1}
        {0, 1}
    }
    {
        {1}
        {1}
        {1}
        {1}
    }
    {
        {1, 1, 1}
        {1, 0, 0}
    }
    {
        {0, 1, 0}
        {1, 1, 1}
    }
    {
        {1, 1, 0}
        {0, 1, 1}
    }
}

iNegs = {
    {
        {0, 1, 1, 1, 0}
        {1, 1, 1, 1, 1}
        {1, 1, 1, 1, 1}
        {1, 1, 1, 1, 1}
        {1, 1, 1, 1, 1}
        {1, 1, 1, 1, 1}
    }
}

bake = (input, removeDupes, desiredW, desiredH) ->
    permuted = {}
    if #input > 2
        permute input, #input, permuted
    else
        permuted = { {input[1], input[2]} }

    baked = {}
    for _, polyos in pairs permuted
        start = os.clock!
        prevPolyos = {polyos[1]}
        for i = 2, #polyos
            pendingPolyos = {}
            for _, prev in pairs prevPolyos
                for _, comb in pairs (combinations polyos[i], prev, desiredW, desiredH)
                    table.insert pendingPolyos, comb
            prevPolyos = deduplicate pendingPolyos

        for i = 1, #prevPolyos
            table.insert baked, prevPolyos[i]
        --print "Baking negatives took #{os.clock! - start} sec."

    if not removeDupes
        return baked
    else
        unduped = {}
        for k, v in pairs baked
            isDupe = false
            for i = 1, #unduped
                if compareMatrices v, unduped[i]
                    isDupe = true
                    break
            if not isDupe
                table.insert unduped, v
        return unduped

checkSolution = (input, bakedNegatives, desiredW, desiredH) ->
    permuted = {}
    if #input > 2
        permute input, #input, permuted
        print #permuted
    else
        permuted = { {input[1], input[2]} }

    for _, polyos in pairs permuted
        start = os.clock!
        prevPolyos = {polyos[1]}
        for i = 2, #polyos
            pendingPolyos = {}
            for _, prev in pairs prevPolyos
                for _, comb in pairs (combinations polyos[i], prev, desiredW, desiredH)
                    table.insert pendingPolyos, comb
            prevPolyos = deduplicate pendingPolyos
        print "Baking polyos took #{os.clock! - start} sec."
        for _, polyo in pairs prevPolyos
            for _, neg in pairs bakedNegatives
                if compareMatrices polyo, neg
                    return true

    return false    
        
        
bakedNegs = bake iNegs, true
printMatrix bakedNegs[1]

start = os.clock!
desiredW, desiredH = nil, nil
--if #bakedNegs == 0
    --desiredH = #area
    --desiredW = #area[1]
success = checkSolution iPolyos, bakedNegs, desiredW, desiredH
print "Solution " .. (success and "found" or "not found")
print "Time elapsed: #{os.clock! - start} sec."
print "Overlay was called #{overlayTimesCalled} times." 