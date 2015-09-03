gl.setup(1280, 720)

local scramble = require "scramble"

util.auto_loader(_G)

function write(font, x, y, text, size, r, g, b, a)
    local s = scramble.scramble(text)
    return function()
        font:write(x, y, s(), size, r, g, b, a)
    end
end

local lines = {
    write(light, 350, 0 * 144, "f/f.n[o", 140, 1   ,.706,0   ,.8),
    write(light, 50 , 1 * 144, "r.d/-]>", 140, .8  ,.8  ,.7  ,.8),
    write(light, 600, 2 * 144, "c.o-n/ ", 140, .863,0   ,.404,.8),
    write(light, 50 , 3 * 144, " / -2.0", 140, .7  ,.7  ,.7  ,.8),
    write(bold,  350, 4 * 144, "1(5).-2", 140, 0   ,.62 ,.878,.8),
}

function node.render()
    for i = 1, #lines do
        lines[i]()
    end
end
