function lerp(a, b, t) return a+(b-a)*t end
function clamp(lo, n, hi) return math.min(math.max(lo, n), hi) end

Loader = { 
    SB_X = -89, -- scoop base is offset this far from loader's X coordinate
    SB_Y1 = 10, -- when in the "down" position, the base is offset this far from loader Y
    SB_Y2 = 0, -- and this far in the "up" position
    
    SP_Y = -22, -- scoop pusher is offset this far from scoop base's calculated Y
    SP_X1 = 26, -- in the normal position, scoop pusher is offset this far from scoop base's calculated X
    SP_X2 = 0, -- in the pushed-forward position, scoop pusher is offset this far from scoop base's calculated X
}
Loader.__index = Loader

function Loader.loadAssets()
    Loader.imgBody = love.graphics.newImage("loader-body.png")  
    Loader.imgScoopBottom = love.graphics.newImage("loader-scoop-bottom.png")  
    Loader.imgScoopPusher = love.graphics.newImage("loader-scoop-pusher.png")  
end

function Loader.new(x, y, facing)
    local o = {}
    setmetatable(o, Loader)
    o.x = x
    o.y = y
    o.facing = facing or 1
    o.lift = 0
    o.push = 0
    return o
end

function Loader:render()
    local sbx, sby, spx, spy

    sbx = self.x + Loader.SB_X * self.facing
    sby = lerp(self.y + Loader.SB_Y1, self.y + Loader.SB_Y2, self.lift)

    spy = sby + Loader.SP_Y
    spx = lerp(sbx + Loader.SP_X1 * self.facing, sbx + Loader.SP_X2 * self.facing, self.push)

    love.graphics.draw(Loader.imgBody, self.x, self.y, 0, self.facing, 1, Loader.imgBody:getWidth() / 2, Loader.imgBody:getHeight() / 2)
    love.graphics.draw(Loader.imgScoopBottom, sbx, sby, 0, self.facing, 1)
    love.graphics.draw(Loader.imgScoopPusher, spx, spy, 0, self.facing, 1)
end

function love.load()
    Loader.loadAssets()
    l1 = Loader.new(100, 100)
    l2 = Loader.new(200, 200, -1)
end

function love.draw()
    l1:render()
    l2:render()
end

function love.update(dt)
    if love.keyboard.isDown("escape") then
        love.event.quit()
    end
    if love.keyboard.isDown("up") then
        l1.lift = clamp(0.0, l1.lift + 0.1, 1.0)
        l2.lift = clamp(0.0, l2.lift + 0.1, 1.0)
    end
    if love.keyboard.isDown("down") then
        l1.lift = clamp(0.0, l1.lift - 0.1, 1.0)
        l2.lift = clamp(0.0, l2.lift - 0.1, 1.0)
    end
    if love.keyboard.isDown("left") then
        l1.push = clamp(0.0, l1.push + 0.1, 1.0)
        l2.push = clamp(0.0, l2.push + 0.1, 1.0)
    end
    if love.keyboard.isDown("right") then
        l1.push = clamp(0.0, l1.push - 0.1, 1.0)
        l2.push = clamp(0.0, l2.push - 0.1, 1.0)
    end
end
