DEBUG = false

function lerp(a, b, t) return a+(b-a)*t end
function clamp(lo, n, hi) return math.min(math.max(lo, n), hi) end

function Class(statics)
    local ct = statics or { }
    ct.__index = ct
    ct.new = function(...)
        local o = {}
        setmetatable(o, ct)
        o:init(...)
        return o
    end
    return ct
end

Box = Class {
    WIDTH = 26,
    HW = 13,
    HEIGHT = 26,
    HH = 13,
    COLORS = {"red", "yellow", "white", "green", "purple"},

    HZ_X = 0,
    HZ_Y = 12,
    HZ_WIDTH = 40,
    HZ_HW = 20,
    HZ_HEIGHT = 16,
    HZ_HH = 8,

    ALL = {}
}

function Box.loadAssets()
    Box.IMG = {}
    for i, v in ipairs(Box.COLORS) do
        Box.IMG[v] = love.graphics.newImage(v .. ".png")
    end
end

-- find a box whose hit zone completely encloses the hit zone centered at (hzx, hzy) 
-- returns first bounded box if found; nil otherwise
function Box.collide(hzx, hzy, hzhw, hzhh)
    local hzx1 = hzx - hzhw
    local hzx2 = hzx + hzhw
    local hzy1 = hzy - hzhh
    local hzy2 = hzy + hzhh

    for b, _ in pairs(Box.ALL) do
        local bzx1 = b.x + Box.HZ_X - Box.HZ_HW
        local bzx2 = b.x + Box.HZ_X + Box.HZ_HW
        local bzy1 = b.y + Box.HZ_Y - Box.HZ_HH
        local bzy2 = b.y + Box.HZ_Y + Box.HZ_HH
        if (hzx1 >= bzx1) and (hzx2 <= bzx2) and (hzy1 >= bzy1) and (hzy2 <= bzy2) then
            return b
        end
    end

    return nil
end

function Box:init(x, y, color)
    self.x = x
    self.y = y
    self.img = Box.IMG[color]
    Box.ALL[self] = true -- put in global set of boxes
end

function Box:draw()
    love.graphics.draw(self.img, self.x, self.y, 0, 1, 1, Box.HW, Box.HH)

    if DEBUG then
        local hzx, hzy
        hzx = self.x + Box.HZ_X
        hzy = self.y + Box.HZ_Y
        
        r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(0.0, 1.0, 0, 1.0)
        love.graphics.rectangle("line", hzx - Box.HZ_WIDTH / 2, hzy - Box.HZ_HEIGHT / 2, Box.HZ_WIDTH, Box.HZ_HEIGHT)
        love.graphics.setColor(r, g, b, a)
    end
end


Controller = Class()

function Controller:init(keymap)
    keymap = keymap or {}
    self.keymap = {
        up = keymap["up"] or "up",
        down = keymap["down"] or "down",
        left = keymap["left"] or "left",
        right = keymap["right"] or "right",
        grab = keymap["grab"] or "space",
    }
end

function Controller:has(dir)
    return love.keyboard.isDown(self.keymap[dir])
end

Loader = Class { 
    SB_X = -74, -- scoop base is offset this far from loader's X coordinate
    SB_Y1 = 12, -- when in the "down" position, the base is offset this far from loader Y
    SB_Y2 = 2, -- and this far in the "up" position
    
    SP_Y = -12, -- scoop pusher is offset this far from scoop base's calculated Y
    SP_X1 = 13, -- in the normal position, scoop pusher is offset this far from scoop base's calculated X
    SP_X2 = -12, -- in the pushed-forward position, scoop pusher is offset this far from scoop base's calculated X

    HZ_X = -5, -- hit-zone x-offset, relative to scoop-base
    HZ_Y = 0, -- hit-zone y_offset, relative to scoop-base
    HZ_WIDTH = 26,
    HZ_HW = 13,
    HZ_HEIGHT = 8,
    HZ_HH = 4,

    CARGO_X = -15,    -- cargo center offset from pusher x/y
    CARGO_Y = -2,

    BOUND_HW = 90, -- half-width of logical loader size (for screen bounding)
    BOUND_HH = 45, -- half-height

    SPEED_X = 100,
    SPEED_Y = 100
}

function Loader.loadAssets()
    Loader.imgBody = love.graphics.newImage("loader-body.png")  
    Loader.imgScoopBottom = love.graphics.newImage("loader-scoop-bottom.png")  
    Loader.imgScoopPusher = love.graphics.newImage("loader-scoop-pusher.png")  
    Loader.imgBodyHW = Loader.imgBody:getWidth() / 2
    Loader.imgBodyHH = Loader.imgBody:getHeight() / 2
    Loader.imgScoopBottomHW = Loader.imgScoopBottom:getWidth() / 2
    Loader.imgScoopBottomHH = Loader.imgScoopBottom:getHeight() / 2
    Loader.imgScoopPusherHW = Loader.imgScoopPusher:getWidth() / 2
    Loader.imgScoopPusherHH = Loader.imgScoopPusher:getHeight() / 2
end

function Loader:init(x, y, facing)
    self.x = x
    self.y = y
    self.facing = facing or 1
    self.lift = 0
    self.push = 0
    self.state = "empty"    -- or lifting, or loaded, or pushing, or retracting, or lowering
    self.controller = nil
    self.cargo = nil
    self.trailer = nil
end

function Loader:attachController(controller)
    self.controller = controller
end

function Loader:targetTrailer(trailer)
    self.trailer = trailer
end

function Loader:update(dt)
    local canMove = true

    if self.state == "lifting" then
        canMove = false
        self.lift = clamp(0.0, self.lift + dt * 4, 1.0)
        if self.lift == 1.0 then
            self.state = "loaded"
        end
    elseif self.state == "pushing" then
        canMove = false
        self.push = clamp(0.0, self.push + dt * 4, 1.0)
        if self.push == 1.0 then
            self.state = "retracting"
            self.trailer:finishLoading(self.cargo)
            self.cargo = nil
        end
    elseif self.state == "retracting" then
        canMove = true
        self.push = clamp(0.0, self.push - dt * 4, 1.0)
        if self.push == 0.0 then
            self.state = "lowering"
        end
    elseif self.state == "lowering" then
        canMove = true
        self.lift = clamp(0.0, self.lift - dt * 4, 1.0)
        if self.lift == 0.0 then
            self.state = "empty"
        end
    end

    if canMove and self.controller then
        -- controller movement
        if self.controller:has("grab") then  
            if self.state == "empty" then
                local sbx, sby, spx, spy, hzx, hzy = self:_calcZones()
                local hitBox = Box.collide(hzx, hzy, Loader.HZ_HW, Loader.HZ_HH)
                if hitBox then
                    self.cargo = hitBox
                    self.state = "lifting"
                end
            elseif self.state == "loaded" then
                local sbx, sby, spx, spy, hzx, hzy = self:_calcZones()
                if self.trailer and self.trailer:readyFor(hzx, hzy, Loader.HZ_HW, Loader.HZ_HH) then
                    self.state = "pushing"
                    self.trailer:startLoading()
                end
            end
        end

        if self.controller:has("left") then
            self.x = self.x - Loader.SPEED_X * dt
        elseif self.controller:has("right") then
            self.x = self.x + Loader.SPEED_X * dt
        end
        if self.controller:has("up") then
            self.y = self.y - Loader.SPEED_Y * dt
        elseif self.controller:has("down") then
            self.y = self.y + Loader.SPEED_Y * dt
        end
        
        -- screen bounding
        if self.x - Loader.BOUND_HW <= 0 then
            self.x = Loader.BOUND_HW
        elseif self.x + Loader.BOUND_HW >= love.graphics.getWidth() then
            self.x = love.graphics.getWidth() - Loader.BOUND_HW
        end
        if self.y - Loader.BOUND_HH <= 0 then
            self.y = Loader.BOUND_HH
        elseif self.y + Loader.BOUND_HH >= love.graphics.getHeight() then
            self.y = love.graphics.getHeight() - Loader.BOUND_HH
        end
    end

    if self.cargo then
        local sbx, sby, spx, spy, hzx, hzy = self:_calcZones()
        self.cargo.x = spx + Loader.CARGO_X * self.facing
        self.cargo.y = spy + Loader.CARGO_Y
    end
end

function Loader:_calcZones()
    local sbx, sby, spx, spy, hzx, hzy
    sbx = self.x + Loader.SB_X * self.facing
    sby = lerp(self.y + Loader.SB_Y1, self.y + Loader.SB_Y2, self.lift)

    spy = sby + Loader.SP_Y
    spx = lerp(sbx + Loader.SP_X1 * self.facing, sbx + Loader.SP_X2 * self.facing, self.push)

    hzx = sbx + Loader.HZ_X * self.facing
    hzy = sby + Loader.HZ_Y 

    return sbx, sby, spx, spy, hzx, hzy
end

function Loader:draw()
    local sbx, sby, spx, spy, hzx, hzy

    sbx, sby, spx, spy, hzx, hzy = self:_calcZones()

    love.graphics.draw(Loader.imgBody, self.x, self.y, 0, self.facing, 1, Loader.imgBodyHW, Loader.imgBodyHH)
    love.graphics.draw(Loader.imgScoopBottom, sbx, sby, 0, self.facing, 1, Loader.imgScoopBottomHW, Loader.imgScoopBottomHH)
    love.graphics.draw(Loader.imgScoopPusher, spx, spy, 0, self.facing, 1, Loader.imgScoopPusherHW, Loader.imgScoopPusherHH)

    if DEBUG then
        local r, g, b, a
        r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(1.0, 0, 0, 1.0)
        love.graphics.rectangle("line", hzx - Loader.HZ_WIDTH / 2, hzy - Loader.HZ_HEIGHT / 2, Loader.HZ_WIDTH, Loader.HZ_HEIGHT)
        love.graphics.setColor(r, g, b, a)
    end
end

Trailer = Class {
    HZ_X = 110,   -- offset from x/y where hit-zone for unloading is centered
    HZ_Y = 10,
    HZ_WIDTH = 40,
    HZ_HW = 20,
    HZ_HEIGHT = 20,
    HZ_HH = 10
}
function Trailer.loadAssets()
    Trailer.imgTrailer = love.graphics.newImage("trailer.png")
    Trailer.imgTrailerHW = Trailer.imgTrailer:getWidth() / 2
    Trailer.imgTrailerHH = Trailer.imgTrailer:getHeight() / 2
end

function Trailer:init(x, y, facing)
    self.x = x
    self.y = y
    self.facing = facing or 1
    self.cargo = {} -- list of cargo items
end

-- is the loader's hit zone contained in ours?
function Trailer:readyFor(hzx, hzy, hzhw, hzhh)
    local hzx1 = hzx - hzhw
    local hzx2 = hzx + hzhw
    local hzy1 = hzy - hzhh
    local hzy2 = hzy + hzhh

    local tzx1 = self.x + (Trailer.HZ_X * self.facing) - Trailer.HZ_HW
    local tzx2 = tzx1 + Trailer.HZ_WIDTH
    local tzy1 = self.y + Trailer.HZ_Y - Trailer.HZ_HH
    local tzy2 = tzy1 + Trailer.HZ_HEIGHT
    if (hzx1 >= tzx1) and (hzx2 <= tzx2) and (hzy1 >= tzy1) and (hzy2 <= tzy2) then
        return true
    end
    return false
end

function Trailer:startLoading()
    self.state = "loading"
end

function Trailer:finishLoading(box)
    self.state = "waiting"
    table.insert(self.cargo, box)
    -- TODO: reposition box into the "initial slot" position exactly
    local tzx1 = self.x + (Trailer.HZ_X * self.facing) - Box.HZ_HW
    local tzy1 = self.y + Trailer.HZ_Y - Box.HZ_HH
    box.x = tzx1
    box.y = tzy1
end

function Trailer:update(dt)
    if self.state == "loading" then
        for i, b in ipairs(self.cargo) do
            b.x = b.x - dt * 100
        end
    end
end

function Trailer:draw()
    love.graphics.draw(Trailer.imgTrailer, self.x, self.y, 0, self.facing, 1, Trailer.imgTrailerHW, Trailer.imgTrailerHH) 
    if DEBUG then
        local hzx, hzy
        hzx = self.x + Trailer.HZ_X * self.facing
        hzy = self.y + Trailer.HZ_Y
        
        r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(0.0, 1.0, 1.0, 1.0)
        love.graphics.rectangle("line", hzx - Trailer.HZ_HW, hzy - Trailer.HZ_HH, Trailer.HZ_WIDTH, Trailer.HZ_HEIGHT)
        love.graphics.setColor(r, g, b, a)
    end
end

function love.load()
    Box.loadAssets()
    Loader.loadAssets()
    Trailer.loadAssets()

    l1 = Loader.new(400, 100)
    l2 = Loader.new(400, 200, -1)
    t1 = Trailer.new(120, 480)
    l1:targetTrailer(t1)

    ctrl1 = Controller.new()
    ctrl2 = Controller.new {
        up = "w",
        down = "s",
        left = "a",
        right = "d",
        grab = "tab"
    }
    l1:attachController(ctrl1)
    l2:attachController(ctrl2)

    updatables = { l1, l2, t1 }
    drawables = { l1, l2, t1}
    for j, c in ipairs(Box.COLORS) do
        for i = 0, 4 do
            local b1 = Box.new(Box.HW + i * (Box.WIDTH + Box.HW), (love.graphics.getHeight() / 3)  + Box.HH + (j - 1) * (Box.HEIGHT + Box.HH), c)
            local b2 = Box.new(love.graphics.getWidth() - (Box.HW + i * (Box.WIDTH + Box.HW)), (2 * (love.graphics.getHeight() / 3)) - (Box.HH + (j - 1) * (Box.HEIGHT + Box.HH)), c)
            table.insert(drawables, b1)
            table.insert(drawables, b2)
        end
    end
end

function love.draw()
    for i, v in ipairs(drawables) do
        v:draw()
    end
end

function love.update(dt)
    if love.keyboard.isDown("escape") then
        love.event.quit()
    end
    for i, v in ipairs(updatables) do
        v:update(dt)
    end
end
