
function centerx(width)
    return (256 - width) * 0.5
end

local starting = false
local y = 318 - 16
local r = 312
local target_r = 0
local target_duration = 1.5
local duration = target_duration

function _init()
    y = 318 - 16
    starting = false
    r = 312
    duration = target_duration
    gfx.camera()
end

function _update()
    if ctrl.touched(0) then
        starting = true
    end

    if starting then
        y = y - 8
        r = juice.powIn2(r, target_r, (target_duration - duration) / target_duration)

        duration = duration - tiny.dt

        if(duration < 0) then
            tiny.exit(1)
        end
    end
end

function _draw()
    gfx.cls(1)
    shape.circlef(centerx(16) + 8, 384 * 0.5, r, 0)
    gfx.to_sheet("transition")

    gfx.cls(8)

    local x = centerx(176)
    local step = 2
    for i = 0, 176, step do
        spr.sdraw(
            x + i, 
            120 + math.cos(4 * math.pi * i / 240 + tiny.t * 8) * 8, 
            40 + i, 
            120, 
            step, 48)
    end

    if((tiny.frame % 60) > 10) then
        spr.sdraw(x, 180, 40, 216, 176, 32)
    end

    spr.sdraw(centerx(48) , 318, 0, 16, 48, 8)
    if starting then
        local before = spr.sheet("transition")
        spr.sdraw()
        spr.sheet(before)
        spr.draw(0, centerx(16), y)
    else
        spr.draw(19 + (tiny.frame * 0.15) % 5, centerx(16), y)
    end

end
