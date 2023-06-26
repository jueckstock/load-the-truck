function lerp(a, b, t) return a+(b-a)*t end
function clamp(lo, n, hi) return math.min(math.max(lo, n), hi) end


Controller = { }
Controller.__index = Controller

function Controller.new(keymap)
    keymap = keymap or {}
    local o = {}
    setmetatable(o, Controller)
    o.keymap = {
        up = keymap["up"] or "up",
        down = keymap["down"] or "down",
        left = keymap["left"] or "left",
        right = keymap["right"] or "right",
        grab = keymap["grab"] or "space",
    }
    return o
end

function Controller:has(dir)
    return love.keyboard.isDown(self.keymap[dir])
end


Loader = { 
    SB_X = -74, -- scoop base is offset this far from loader's X coordinate
    SB_Y1 = 12, -- when in the "down" position, the base is offset this far from loader Y
    SB_Y2 = 2, -- and this far in the "up" position
    
    SP_Y = -12, -- scoop pusher is offset this far from scoop base's calculated Y
    SP_X1 = 13, -- in the normal position, scoop pusher is offset this far from scoop base's calculated X
    SP_X2 = -12, -- in the pushed-forward position, scoop pusher is offset this far from scoop base's calculated X

    HZ_X = -14, -- hit-zone x-offset, relative to scoop-base
    HZ_Y = 0, -- hit-zone y_offset, relative to scoop-base

    BOUND_HW = 90, -- half-width of logical loader size (for screen bounding)
    BOUND_HH = 45, -- half-height

    SPEED_X = 100,
    SPEED_Y = 100
}
Loader.__index = Loader

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

function Loader.new(x, y, facing)
    local o = {}
    setmetatable(o, Loader)
    o.x = x
    o.y = y
    o.facing = facing or 1
    o.lift = 0
    o.push = 0
    o.state = "empty"    -- or lifting, or loaded, or pushing, or retracting, or lowering
    return o
end

function Loader:update(dt, controller)
    if self.state == "lifting" then
        self.lift = clamp(0.0, self.lift + dt * 4, 1.0)
        if self.lift == 1.0 then
            self.state = "loaded"
        end
    elseif self.state == "pushing" then
        self.push = clamp(0.0, self.push + dt * 4, 1.0)
        if self.push == 1.0 then
            self.state = "retracting"
            -- TODO: detach carried object here
        end
    elseif self.state == "retracting" then
        self.push = clamp(0.0, self.push - dt * 4, 1.0)
        if self.push == 0.0 then
            self.state = "lowering"
        end
    elseif self.state == "lowering" then
        self.lift = clamp(0.0, self.lift - dt * 4, 1.0)
        if self.lift == 0.0 then
            self.state = "empty"
        end
    else -- free to move
        -- controller movement
        if controller:has("grab") then
            if self.state == "empty" then
                self.state = "lifting"
            elseif self.state == "loaded" then
                self.state = "pushing"
            end
        end

        if controller:has("left") then
            self.x = self.x - Loader.SPEED_X * dt
        elseif controller:has("right") then
            self.x = self.x + Loader.SPEED_X * dt
        end
        if controller:has("up") then
            self.y = self.y - Loader.SPEED_Y * dt
        elseif controller:has("down") then
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
end

function Loader:render()
    local sbx, sby, spx, spy, hzx, hzy, r, g, b, a

    sbx = self.x + Loader.SB_X * self.facing
    sby = lerp(self.y + Loader.SB_Y1, self.y + Loader.SB_Y2, self.lift)

    spy = sby + Loader.SP_Y
    spx = lerp(sbx + Loader.SP_X1 * self.facing, sbx + Loader.SP_X2 * self.facing, self.push)

    hzx = sbx + Loader.HZ_X * self.facing
    hzy = sby + Loader.HZ_Y 

    love.graphics.draw(Loader.imgBody, self.x, self.y, 0, self.facing, 1, Loader.imgBodyHW, Loader.imgBodyHH)
    love.graphics.draw(Loader.imgScoopBottom, sbx, sby, 0, self.facing, 1, Loader.imgScoopBottomHW, Loader.imgScoopBottomHH)
    love.graphics.draw(Loader.imgScoopPusher, spx, spy, 0, self.facing, 1, Loader.imgScoopPusherHW, Loader.imgScoopPusherHH)

    r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(1.0, 0, 0, 1.0)
    love.graphics.rectangle("line", hzx - 5, hzy - 5, 10, 10)
    love.graphics.setColor(r, g, b, a)
end

function love.load()
    Loader.loadAssets()

    l1 = Loader.new(100, 100)
    l2 = Loader.new(200, 200, -1)

    ctrl1 = Controller.new()
    ctrl2 = Controller.new {
        up = "w",
        down = "s",
        left = "a",
        right = "d",
        grab = "tab"
    }
end

function love.draw()
    l1:render()
    l2:render()
end

function love.update(dt)
    if love.keyboard.isDown("escape") then
        love.event.quit()
    end
    l1:update(dt, ctrl1)
    l2:update(dt, ctrl2)
end
