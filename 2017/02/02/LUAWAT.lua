local function bind(f, ...)
    local x = {...}
    return function()
        return f(unpack(x))
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
