-- pack function arguments. Use unpack2() for unpacking! This differs
-- from the builtin method `x = {...}; unpack(x)` in that it unpacks the
-- correct number of arguments, even in the presence of nil values.
function pack2(...)
    return {n = select('#', ...), ...}
end

-- unpack function arguments that were packed by pack2()
function unpack2(t, start)
    return unpack(t, start, t.n)
end

-- concat two parameter packs that were packed by pack2. This is
-- necessary to prevent multiple nils being joined at the end of the first
-- pack.
function pack_concat(a, b)
    local ret = {n = a.n+b.n, unpack2(a)}
    for i = 1, b.n do
        ret[a.n+i] = b[i]
    end
    return ret
end

-- bind initial arguments to a function (partial)
-- bind(f, x)(y) = f(x, y)
function bind(func, ...)
    local head = pack2(...)
    return function(...)
        local tail = pack2(...)
        local args = pack_concat(head, tail)
        return func(unpack2(args))
    end
end


bind(print, 1, 2)()
bind(print, 1, 2, 3)()
bind(print, 1, 2, 3, nil)()
bind(print, 1, 2, 3, nil, 5)()
bind(print, 1, 2, 3, nil, 5, nil)()
bind(print, 1, 2, 3, nil, 5, nil, 7)()
bind(print, 1, 2, 3, nil, 5, nil, 7, nil)()
bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9)()
bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil)()
bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil)()
bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil)()
bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil)()
bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil, nil)()
bind(print, 1, 2, 3, nil, 5, nil, 7, nil, 9, nil, nil, nil, nil, nil, nil)()

