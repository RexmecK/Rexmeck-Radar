require "/scripts/vec2.lua"
include "chunkPosition"
include "chunkManager"
include "entityTracker"

module = {}
module.hovering = false
module.includedTypes = {"creature"}

function module:init()
    self.sizeCanvas = self.canvas:size()
    self.chunkManager = chunkManager:new()
    self.viewOffset = vec2.mul(self.sizeCanvas, -0.5)
    self.mousePosition = {0,0}
    self.playerPos = {0,0}
    self.playerId = player.id()
    self.middle = vec2.mul(self.sizeCanvas, 0.5)
end

function module:update(dt)
    self.playerId = player.id()
    self.playerPos = world.entityPosition(player.id())
    self:updateMouse()

    if self.playerPos then
        local clock = os.clock()
        self.viewPos = vec2.add(self.playerPos, self.viewOffset)
        local size = self.canvas:size()

        --update Views
        local chunkPos = chunkPosition(vec2.sub(self.viewPos, {32,32}))
        local viewChunkSize = vec2.add(chunkPosition(self.sizeCanvas), {1,1})
        self.chunkManager.view = {chunkPos, vec2.add(chunkPos, viewChunkSize)}
        self.chunkManager:update(dt)
        entityTracker:update(dt)
        self:updateCanvas()
        
        --debug
        world.debugText("update : "..(os.clock() - clock), self.playerPos, "white")
        world.debugText("hovering : "..tostring(self.hovering), vec2.add(self.playerPos, {0,1}), "white")
    end
end

function module:renderEntities()
    local query = world.entityQuery(
        vec2.sub(self.playerPos, self.middle),
        vec2.add(self.playerPos, self.middle),
        {includedTypes = self.includedTypes}
    )

    local hovering = world.entityQuery(
        vec2.add(self.viewPos, self.mousePosition),
        4,
        {
            order = "nearest",
            includedTypes = self.includedTypes
        }
    )

    if hovering[1] then
        self.hovering = hovering[1]
    else
        self.hovering = false
    end

    if entityTracker.position then
        self.canvas:drawLine(
            vec2.sub(self.playerPos, self.viewPos),
            vec2.sub(entityTracker.position, self.viewPos ),
            "#f006",
            4
        )
    end

    for i,v in pairs(query) do
        local relative = world.distance(world.entityPosition(v), self.viewPos)
        local color = "#fff"

        if v == self.playerId then
            color = "#ff0"
        end
        
        if self.hovering and self.hovering == v then
            color = "#0f0"
            --shows informations about the entity
            local infos = {
                Aggressive = world.entityAggressive(v),
                Money = world.entityCurrency(v, "money"),
                Description = world.entityDescription(v),
                Type = world.entityType(v),
                Name = world.entityName(v),
                Gender = world.entityGender(v),
                Species = world.entitySpecies(v),
                Health = world.entityHealth(v),
                Trackable = type(world.entityUniqueId(v)) == "string",
            }
            if infos.Health then
                infos.Health = infos.Health[1].."/"..infos.Health[2]
            end

            local textHOffset = -8
            for i,v in pairs(infos) do
                self.canvas:drawText(
                    i..": "..tostring(v),
                    {
                        position = vec2.add(relative, {0,textHOffset}),
                        horizontalAnchor = "mid",
                        verticalAnchor = "mid",
                        wrapWidth = nil
                    },
                    8,
                    "#fff"
                )
                textHOffset = textHOffset - 8
            end
            --portrait
            for i,v in ipairs(world.entityPortrait(v, "full") or {}) do
                self.canvas:drawImage(v.image, vec2.add(vec2.add(relative, {0,32}), v.position), 1, "#fff", true)
            end

        end

        
        self.canvas:drawLine(
            vec2.add(relative, {0,-2}),
            vec2.add(relative, {0,2}),
            color,
            8
        )
        self.canvas:drawLine(
            vec2.add(relative, {0,-3}),
            vec2.add(relative, {0,3}),
            color.."4",
            12
        )
    end

end

function module:updateCanvas()
    self.canvas:clear()
    local view = self.chunkManager:getView()
    self.canvas:drawRect({0,0,self.sizeCanvas[1], self.sizeCanvas[2]}, "#000")
    --render Chunks
    for i,v in pairs(view) do
        if v.image then -- loaded chunk

            self.canvas:drawImage(
                v.image, 
                vec2.sub(v.position, self.viewPos),
                1,
                "#fff",
                false
            )
        elseif v.square then -- if its a loading chunk
            local relative = world.distance(v.position, self.viewPos)

            self.canvas:drawLine(
                vec2.add(relative, {16,0}),
                vec2.add(relative, {16,32} ), 
                "#"..v.square, 
                64
            )
        end
    end
    self:renderEntities()
end

function module:inCanvas(point)
    return 
        (self.rect[3] - self.rect[1] + 30) > point[1] and 
        (self.rect[4] - self.rect[2]) > point[2] and 
        (point[1] > self.rect[1]) and 
        (point[2] > self.rect[2])
end

function module:updateMouse()
    self.mousePosition = self.canvas:mousePosition()
    if self.mouseDown[1] and self.mouseDown[1][2] then
        if self:inCanvas(self.mousePosition) then
            local adds = vec2.sub(self.mouseDown[1][1], self.mousePosition)
            self.mouseDown[1][1] = self.mousePosition
            self.viewOffset = vec2.add(self.viewOffset, adds)
        else
            self.mouseDown[1][2] = false
        end
    end
end

module.mouseDown = {}
function module:handleMouse(position, button, isdown)
    if isdown and button == 0 and self.hovering then
        entityTracker:track(self.hovering)
    else
        self.mouseDown[button + 1] = {position, isdown}
    end
end

function module:uninit()

end