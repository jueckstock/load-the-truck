Loader = { facing = 1 }
Loader.__index = Loader

function Loader.loadAssets()
    Loader.imgBody = love.graphics.newImage("loader-body.png")  
end

function Loader.new(x, y, facing)
    local o = {}
    setmetatable(o, Loader)
    o.x = x
    o.y = y
    o.facing = facing or 1
    return o
end

function Loader:render()
    love.graphics.draw(Loader.imgBody, self.x, self.y, 0, self.facing, 1)
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
