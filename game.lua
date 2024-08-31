local gravity = nil

local bob = nil

local BOB_STATE_JUMP = 0
local BOB_STATE_FALL = 1
local BOB_STATE_HIT = 2
local BOB_JUMP_VELOCITY = -5
local BOB_MOVE_VELOCITY = 10

local Bob = {
    state = BOB_STATE_FALL,
    stateTime = 0,
    accel = 0,
    velocity = nil,
    y_camera = 0,
    coins = 0,
    prev = {}
}

Bob.create = function(data)

    local dither = {0xA5A5, 0x8181, 0x8080, 0x0101, 0x1010}
    local b = new(Bob, data)
    b.velocity = vec2.create()
    for i = 1, 5 do
        table.insert(b.prev, {
            x = b.x,
            y = b.y,
            d = dither[i]
        })
    end
    return b
end

Bob.hitSquirrel = function(self)
    self.velocity = vec2.create()
    self.state = BOB_STATE_HIT
    self.stateTime = 0
end

Bob.hitPlatform = function(self)
    self.velocity.y = BOB_JUMP_VELOCITY
    self.state = BOB_STATE_JUMP
    self.stateTime = 0
end

Bob.hitSpring = function(self)
    self.velocity.y = BOB_JUMP_VELOCITY * 1.5
    self.state = BOB_STATE_JUMP
    self.stateTime = 0
end

Bob._update = function(self)
    local touch = ctrl.touching(0)
    if touch == nil then

    elseif touch.x < self.x + self.width * 0.5 then
        self.accel = 2
    else
        self.accel = -2
    end

    if ctrl.pressing(keys.left) then
        self.accel = 2
    elseif ctrl.pressing(keys.right) then
        self.accel = -2
    end

    if (self.state ~= BOB_STATE_HIT) then
        self.velocity.x = -self.accel / 10 * BOB_MOVE_VELOCITY
    end

    self.velocity = vec2.add(self.velocity, gravity)
    self.x = self.x + self.velocity.x
    self.y = self.y + self.velocity.y
    if (self.velocity.y > 0 and self.state ~= BOB_STATE_HIT) then
        if self.state ~= BOB_STATE_JUMP then
            self.state = BOB_STATE_JUMP
            self.stateTime = 0
        end
    end

    if (self.velocity.y < 0 and self.state ~= BOB_STATE_HIT) then
        if self.state ~= BOB_STATE_FALL then
            self.state = BOB_STATE_FALL
            self.stateTime = 0
        end
    end

    if self.x < 0 - self.width then
        self.x = self.world_width
    end

    if self.x > self.world_width then
        self.x = 0
    end

    self.stateTime = self.stateTime + tiny.dt

    self.y_camera = juice.powIn2(self.y - self.world_height * 0.5, self.y_camera, 0.98)

    local prev = self
    for i = 1, #self.prev do
        self.prev[i].x = juice.linear(prev.x, self.prev[i].x, 0.8)
        self.prev[i].y = juice.linear(prev.y, self.prev[i].y, 0.8)
        prev = self.prev[i]
    end
    gfx.camera(0, math.max(self.y_camera, 0))

    -- out of screen
    if self.y < -16 then
        self.y = -60
    end
end

Bob._draw = function(self)
    local spr_index = 0
    if self.velocity.y > 0 then
        spr_index = 1
    end

    for i = #self.prev, 1, -1 do
        gfx.dither(self.prev[i].d)
        local x, y = self.prev[i].x, self.prev[i].y
        spr.draw(spr_index, x, y, self.accel > 0)
    end
    gfx.dither()

    spr.draw(spr_index, self.x, self.y, self.accel > 0)

    -- draw score
    print(self.coins, 2, 10 + self.y_camera)
end

local EndTitle = {
    x = 8,
    y = -160,
    target_y = 160,
    ttl = nil
}

EndTitle._update = function(self)
    if not self.ttl then
        return
    end

    if (self.ttl < 0) then
        self.ttl = self.ttl + tiny.dt
        self.y = juice.powIn2(self.target_y, self.y, 0.98)
        if self.ttl > 0 then
            self.y = self.target_y
        end
    else
        self.ttl = self.ttl + tiny.dt
    end
end

EndTitle._draw = function(self)
    if not self.ttl then
        return
    end

    local step = 2
    for i = 0, 240, step do
        spr.sdraw(self.x + i, self.y + math.cos(4 * math.pi * i / 240 + tiny.t * 8) * 8, 8 + i, 184, step, 33)
    end
end

local EndLevel = {
    candles = {}
}

EndLevel.create = function(data)
    local e = new(EndLevel, data)
    local step = 2 * math.pi / 8
    for i = 1, 8 do

        table.insert(e.candles, {
            i = i,
            x = math.cos(i * step + tiny.t),
            y = math.sin(i * step + tiny.t)
        })
    end
    return e
end

EndLevel._update = function(self)
    local step = 2 * math.pi / 8
    for e in all(self.candles) do
        e.x = math.cos(e.i * step + tiny.t * 1.5)
        e.y = math.sin(e.i * step + tiny.t * 1.5)
    end
end

EndLevel._draw = function(self)
    for e in all(self.candles) do

        spr.sdraw(self.x + e.x * self.width, self.y + e.y * self.height, 72, 48, 9, 7)
    end
end

local EndScreen = {}

EndScreen.create = function(data)
    return new(EndScreen, data)
end

local PLATFORM_TYPE_STATIC = 0
local PLATFORM_TYPE_MOVING = 1
local PLATFORM_STATE_NORMAL = 0
local PLATFORM_STATE_PULVERIZING = 1
local PLATFORM_PULVERIZE_TIME = 0.2 * 4
local PLATFORM_VELOCITY = 2;

local decals_y = {48, 64, 80, 96, 112, 128, 128, 128}

local Platform = {
    type = PLATFORM_TYPE_STATIC,
    state = PLATFORM_STATE_NORMAL,
    stateTime = 0,
    velocity = nil,
    position = nil
}

Platform.pulverize = function(self)
    self.state = PLATFORM_STATE_PULVERIZING
    self.stateTime = 0
    self.velocity.x = 0
end

Platform.create = function(data)
    local p = new(Platform, data)
    p.velocity = vec2.create()

    if (p.customFields["Type"] == "MOVING") then
        p.type = PLATFORM_TYPE_MOVING
        p.velocity.x = PLATFORM_VELOCITY
    else
        p.type = PLATFORM_TYPE_MOVING
    end

    p.decals_y = math.rnd(decals_y)
    return p
end

Platform._update = function(self)
    if self.type == PLATFORM_TYPE_MOVING then
        self.x = self.x + self.velocity.x

        if self.x < 0 then
            self.velocity.x = self.velocity.x * -1
            self.x = 0
        end

        if self.x > self.world_width - self.width then
            self.velocity.x = self.velocity.x * -1
            self.x = self.world_width - self.width
        end
    end

    if self.state == PLATFORM_STATE_PULVERIZING and self.stateTime > PLATFORM_PULVERIZE_TIME then
        -- to be deleted
        return true
    end

    self.stateTime = self.stateTime + tiny.dt

    return false

end

Platform._draw = function(self)

    spr.sdraw(self.x, self.y - 16, 0, self.decals_y, self.width, 16)
    if self.state == PLATFORM_STATE_PULVERIZING then
        if (tiny.frame % 15) < 7 then
            spr.sdraw(self.x, self.y, 0, 32, self.width, self.height)
        else
            spr.sdraw(self.x, self.y, 0, 16, self.width, self.height)
        end
    else
        spr.sdraw(self.x, self.y, 0, 16, self.width, self.height)
    end
end

local Particles = {
    x = 0,
    y = 0,
    r = 4,
    c = 6,
    ttl = 0.6
}

local particles_conf = {{
    accel = 0.05,
    r = 2,
    ttl = 0.7
}, {
    accel = -0.05,
    r = 2,
    ttl = 0.7
}, {
    accel = 0.25,
    r = 4,
    ttl = 0.5
}, {
    accel = -0.25,
    r = 4,
    ttl = 0.5
}, {
    accel = 0.2,
    r = 3,
    ttl = 0.6
}, {
    accel = -0.2,
    r = 3,
    ttl = 0.6
}, {
    accel = 0.15,
    r = 3,
    ttl = 0.7
}, {
    accel = -0.15,
    r = 3,
    ttl = 0.7
}}

Particles.create = function(i, x, y)
    local r = particles_conf[i].r
    local xx = x + 8
    local a = particles_conf[i].accel
    local ttl = particles_conf[i].ttl
    local p = new(Particles, {
        x = xx,
        y = y + 15,
        r = r,
        r_start = r,
        ttl = ttl,
        accel = a
    })
    return p
end

Particles.createRadial = function(x, y, angle)
    local r = 4
    local xx = x + math.cos(angle) * 8
    local yy = y + math.sin(angle) * 8
    local a = 1
    local ttl = 0.2
    local p = new(Particles, {
        x = xx,
        y = yy,
        r = r,
        r_start = r,
        ttl = ttl,
        radial = true,
        accel_x = a * math.cos(angle),
        accel_y = a * math.sin(angle),
        c = 11
    })
    return p
end

Particles._update = function(self)
    self.ttl = self.ttl - tiny.dt

    if self.radial then
        self.x = self.x + self.accel_x
        self.y = self.y + self.accel_y

        self.r = juice.powIn2(0, self.r, 0.98)
    else
        self.r = juice.powOut2(self.r_start, 0, 0.5 - self.ttl)
        self.x = self.x + self.accel
    end
    return self.ttl < 0
end

Particles._draw = function(self)
    shape.circlef(self.x, self.y, self.r, self.c)
end

local Coins = {
    touched = false,
    target_x = 0,
    target_y = 0
}

Coins.create = function(data)
    return new(Coins, data)
end

Coins._update = function(self)
    if (self.touched) then
        -- move coins in the uperleft
        self.target_y = 8 + bob.y - bob.world_height * 0.5

        self.x = juice.powIn2(self.target_x, self.x, 0.98)
        if not self.fixed then
            self.y = juice.powIn2(self.target_y, self.y, 0.98)
        else
            self.y = 8 + bob.y_camera
        end
        if (math.abs(self.target_y - self.y) < 2) then
            self.fixed = true
        end
    end
end

Coins._draw = function(self)
    function cycleValue(x)
        local cycle_length = 8
        local index = (x - 1) % cycle_length
        if index < 4 then
            return index
        else
            return cycle_length - index - 1
        end
    end

    if self.touched then
        spr.sdraw(self.x, self.y, 96 + 8, 0, 8, 8)
    else
        local offset = cycleValue(math.ceil(tiny.frame * 0.2))
        spr.sdraw(self.x, self.y, 96 + offset * 8, 0, 8, 8)
    end
end

local platforms = {}
local particles = {}
local coins = {}
local endLevel = nil
local endScreen = nil
local endTitle = nil

function _init(w, h)
    platforms = {}
    coins = {}
    gravity = vec2.create(0, 0.1)
    for e in all(map.entities["Bob"]) do
        bob = Bob.create(e)
        bob.world_width = w
        bob.world_height = h
    end

    for e in all(map.entities["Coins"]) do
        table.insert(coins, Coins.create(e))
    end

    for e in all(map.entities["Platform"]) do
        local p = Platform.create(e)
        p.world_width = w
        table.insert(platforms, p)
    end

    for e in all(map.entities["EndLevel"]) do
        endLevel = EndLevel.create(e)
    end

    for e in all(map.entities["EndScreen"]) do
        endScreen = EndScreen.create(e)
    end

    endTitle = new(EndTitle)

    bob.y_camera = bob.y - h * 0.5
    gfx.camera(0, bob.y_camera)
end

function overlaps(self, r)
    return self.x < r.x + r.width and self.x + self.width > r.x and self.y < r.y + r.height and self.y + self.height >
               r.y
end

function checkCollisions()
    for c in all(coins) do
        if not c.touched and overlaps(bob, c) then
            bob.coins = bob.coins + 1
            c.touched = true
            c.target_x = 8 + bob.coins * 4
            c.index = bob.coins

            local step = math.pi * 2 / 8
            for i = 1, 8 do
                table.insert(particles, Particles.createRadial(c.x, c.y, i * step))
            end
        end
    end

    if overlaps(bob, endScreen) then
        bob.velocity.y = BOB_JUMP_VELOCITY * 5
        endTitle.ttl = -3
    end

    if bob.velocity.y < 0 then
        return
    end

    for p in all(platforms) do
        if p.y > bob.y then
            if overlaps(p, bob) then
                bob:hitPlatform()
                for i = 1, #particles_conf do
                    table.insert(particles, Particles.create(i, bob.x, bob.y))
                end

                if math.rnd(100) > 50 then
                    p:pulverize()
                end
            end
        end
    end
end

function _update()
    if ctrl.pressed(keys.space) then
        _init(256, 256)
    end
    bob:_update()

    for i, e in rpairs(platforms) do
        if e:_update() then
            table.remove(platforms, i)
        end
    end

    for i, e in rpairs(particles) do
        if e:_update() then
            table.remove(particles, i)
        end
    end

    for i, c in rpairs(coins) do
        if (c:_update()) then
            table.remove(coins, i)
        end
    end

    table.sort(coins, function(a, b)
        if a.index == nil and b.index == nil then
            return false
        elseif a.index == nil then
            return false
        elseif b.index == nil then
            return true
        else
            return a.index < b.index
        end
    end)

    if bob.state ~= BOB_STATE_HIT then
        checkCollisions()
    end

    if bob.y > map.height() then
        -- end game
        debug.console("end game")
    end

    endLevel:_update()
    endTitle:_update()
end

function _draw()
    gfx.cls(8)
    map.draw()
    for e in all(platforms) do
        e:_draw()
    end

    for e in all(particles) do
        e:_draw()
    end

    for c in all(coins) do
        c:_draw()
    end

    endLevel:_draw()

    bob:_draw()

    endTitle:_draw()
end
