gl.setup(1280, 720)

font = resource.load_font("Oswald-Medium.ttf")

node.alias("room")

local json = require "json"

-- Configure room here
local SAAL = "attraktor"

util.auto_loader(_G)

util.file_watch("schedule.json", function(content)
    print("reloading schedule")
    talks = json.decode(content)
end)

util.file_watch("config.json", function(content)
    local config = json.decode(content)
    if sys.get_env then
        saal = config.devices[sys.get_env("SERIAL")]
    end
    if not saal then
        print("using statically configured saal identifier")
        saal = SAAL
    end
    print(saal)
    rooms = config.rooms
    room = config.rooms[saal]
end)

local base_time = N.base_time or 0
local current_talk
local all_talks = {}
local day = 0

function get_now()
    return base_time + sys.now()
end

function check_next_talk()
    local now = get_now()
    local room_next = {}
    for idx, talk in ipairs(talks) do
        if rooms[talk.place] and not room_next[talk.place] and talk.unix + 25 * 60 > now then 
            room_next[talk.place] = talk
        end
    end

    for room, talk in pairs(room_next) do
        talk.lines = wrap(talk.title, 40)
    end

    if room_next[saal] then
        current_talk = room_next[saal]
    else
        current_talk = nil
    end

    all_talks = {}
    for room, talk in pairs(room_next) do
        if current_talk and room ~= current_talk.place then
            all_talks[#all_talks + 1] = talk
        end
    end
    table.sort(all_talks, function(a, b) 
        if a.unix < b.unix then
            return true
        elseif a.unix > b.unix then
            return false
        else
            return a.place < b.place
        end
    end)
end

function wrap(str, limit, indent, indent1)
    limit = limit or 72
    local here = 1
    local wrapped = str:gsub("(%s+)()(%S+)()", function(sp, st, word, fi)
        if fi-here > limit then
            here = st
            return "\n"..word
        end
    end)
    local splitted = {}
    for token in string.gmatch(wrapped, "[^\n]+") do
        splitted[#splitted + 1] = token
    end
    return splitted
end

local clock = (function()
    local base_time = N.base_time or 0

    local function set(time)
        base_time = tonumber(time) - sys.now()
    end

    util.data_mapper{
        ["clock/midnight"] = function(since_midnight)
            set(since_midnight)
        end;
    }

    local left = 0

    local function get()
        local time = (base_time + sys.now()) % 86400
        return string.format("%d:%02d", math.floor(time / 3600), math.floor(time % 3600 / 60))
    end

    return {
        get = get;
        set = set;
    }
end)()

check_next_talk()

util.data_mapper{
    ["clock/set"] = function(time)
        base_time = tonumber(time) - sys.now()
        N.base_time = base_time
        check_next_talk()
        print("UPDATED TIME", base_time)
    end;
    ["clock/day"] = function(new_day)
        print("DAY", new_day)
        day = new_day
    end;
}

function switcher(screens)
    local current_idx = 1
    local current = screens[current_idx]
    local switch = sys.now() + current.time
    local switched = sys.now()

    local blend = 0.5
    
    local function draw()
        local now = sys.now()

        local percent = ((now - switched) / (switch - switched)) * 3.14129 * 2 - 3.14129
        progress:use{percent = percent}
        white:draw(WIDTH-50, HEIGHT-50, WIDTH-10, HEIGHT-10)
        progress:deactivate()

        if now - switched < blend then
            local delta = (switched - now) / blend
            gl.pushMatrix()
            gl.translate(WIDTH/2, 0)
            gl.rotate(270-90 * delta, 0, 1, 0)
            gl.translate(-WIDTH/2, 0)
            current.draw()
            gl.popMatrix()
        elseif now < switch - blend then
            current.draw(now - switched)
        elseif now < switch then
            local delta = 1 - (switch - now) / blend
            gl.pushMatrix()
            gl.translate(WIDTH/2, 0)
            gl.rotate(90 * delta, 0, 1, 0)
            gl.translate(-WIDTH/2, 0)
            current.draw()
            gl.popMatrix()
        else
            current_idx = current_idx + 1
            if current_idx > #screens then
                current_idx = 1
            end
            current = screens[current_idx]
            switch = now + current.time
            switched = now
        end
    end
    return {
        draw = draw;
    }
end

content = switcher{
    {
--[[
        time = 20;
        draw = function()
            redU(400, 200, "Other rooms", 80)
            white:draw(0, 300, WIDTH, 302, 0.6)
            y = 320
            local time_sep = false
            if #all_talks > 0 then
                for idx, talk in ipairs(all_talks) do
                    if not time_sep and talk.unix > get_now() then
                        if idx > 1 then
                            y = y + 5
                            white:draw(0, y, WIDTH, y+2, 0.6)
                            y = y + 20
                        end
                        time_sep = true
                    end

                    local alpha = 1
                    if not time_sep then
                        alpha = 0.3
                    end
                    blueU(30, y, talk.start, 50)
                    redU(190, y, talk.place, 50)
                    yellow(450, y, talk.lines[math.floor((sys.now()/2) % #talk.lines)+1], 50)
                    y = y + 60
                end
            else
                yellow(400, 330, "No other talks.", 50, 1,1,1,1)
            end
        end
    }, {
        time = 30;
        draw = function()
            if not current_talk then
                redU(400, 200, "Next session...", 80, 1,1,1,1)
                white:draw(0, 300, WIDTH, 302, 0.6)
                redU(400, 330, "Nope. That's it.", 80)

            else
                local delta = current_talk.unix - get_now()
                if delta > 0 then
                    redU(400, 200, "Next session", 80)
                else
                    redU(400, 200, "This session", 80)
                end
                white:draw(0, 300, WIDTH, 302, 0.6)

                blue(130, 330, current_talk.start, 50, 1,1,1,1)
                if delta > 0 then
                    blue(130, 330 + 60, string.format("in %d min", math.floor(delta/60)+1), 50)
                end
                for idx, line in ipairs(current_talk.lines) do
                    if idx >= 5 then
                        break
                    end
                    yellow(400, 330 - 60 + 60 * idx, line, 50)
                end
                for i, speaker in ipairs(current_talk.speakers) do
                    blue(400, 510 + 50 * i, speaker, 50)
                end
            end
        end
    }, {
        time = 10;
        draw = function(t)
            redU(400, 200, "Info", 80)

            white:draw(0, 300, WIDTH, 302, 0.6)

            blueU(30, 320, "WC", 50)
            yellow(400, 320, "Im Keller", 50)

            blueU(30, 380, "Spenden", 50)
            yellow(400, 380, "Box am Tresen - Kosten noch nicht gedeckt", 50)

            blueU(30, 480, "IRC", 50)
            yellow(400, 480, room.irc, 50)

            blueU(30, 540, "Twitter", 50)
            yellow(400, 540, room.twitter, 50)
        end
    }, {
--]]
        time = 60;
        draw = function(t)
            redU(110, 200, "PUBLIC SERVICE ANNOUNCEMENT", 80)

            white:draw(0, 300, WIDTH, 302, 0.6)

            yellow(115, 400, "Danke an die fleissigen Küchenhelfer!", 70)
        end
    },
}

function redU(x, y, text, size)
    red(x, y, string.upper(text), size)
end

function red(x, y, text, size)
    font:write(x, y, text, size, 0.894, 0.251, 0.506, 1)
end

function yellowU(x, y, text, size)
    yellow(x, y, string.upper(text), size)
end

function yellow(x, y, text, size)
    font:write(x, y, text, size, 1.0, 0.776, 0.251, 1)
end

function blueU(x, y, text, size)
    blue(x, y, string.upper(text), size)
end

function blue(x, y, text, size)
    font:write(x, y, text, size, 0.251, 0.714, 0.906, 1)
end

function node.render()
    gl.clear(0.1, 0.1, 0.1, 1)

    if base_time == 0 then
        return
    end

    util.draw_correct(logo, 20, 20, 300, 120)

    yellowU(310, 20, saal, 80)
    blueU(730, 20, clock.get(), 80)
    redU(WIDTH-300, 20, string.format("Day %d", day), 80)

    local fov = math.atan2(HEIGHT, WIDTH*2) * 360 / math.pi
    gl.perspective(fov, WIDTH/2, HEIGHT/2, -WIDTH,
                        WIDTH/2, HEIGHT/2, 0)
    content.draw()
end
