poly1 = {
    {0, 1, 0}
    {1, 0, 1}
    {0, 1, 0}
}
poly2 = {
    {2, 0, 2}
    {0, 2, 0}
    {2, 0, 2}
}
poly3 = {
    {1, 1, 0}
    {0, 1, 1}
}
poly4 = {
    {1, 1, 1}
    {0, 1, 0}
}

sort = (a, b) ->
    if a < b
        return a, b
    else
        return b, a

overlay = (m1, m2, dstX, dstY) ->
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

    overlapping = false
    loopedAtLeastOnce = false
    for y = 0, by - ay
        m1y = is_m1_topmost and (ay + y) or y + 1
        m2y = (not is_m1_topmost) and (ay + y) or y + 1
        for x = 0, bx - ax
            loopedAtLeastOnce = true
            m1x = is_m1_leftmost and (ax + x) or x + 1
            m2x = (not is_m1_leftmost) and (ax + x) or x + 1
            
            m1v, m2v = nil, nil
            if m1[m1y]
                m1v = m1[m1y][m1x]
            if m2[m2y]
                m2v = m2[m2y][m2x]

            print m1v or -1, m2v or -1
            if m1v ~= 0 and m2v ~= 0
                overlapping = true
                --break

        --if overlapping
            --break

    if not overlapping and loopedAtLeastOnce
        w = maxx - minx - 1
        h = maxy - miny - 1
        m1x = is_m1_leftmost and 1
        m1y = is_m1_topmost and 1
        return { m1, m2, true, w, h, m1x, m1y, m1w, m1h, m2x, m2y, m2w, m2h }
    
    return false

moon = require "moon"

print overlay poly1, poly2, 1, -1