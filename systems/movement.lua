-- systems/movement.lua
-- Movement system: applies velocity, handles collision, path following.

local Movement = {}

function Movement.update(entityId, ecs, world, dt)
    local pos = ecs:getComponent(entityId, "Position")
    local vel = ecs:getComponent(entityId, "Velocity")
    if not pos or not vel then return end

    -- Speed cap
    local speed = math.sqrt(vel.vx * vel.vx + vel.vy * vel.vy)
    if speed > vel.maxSpeed then
        local scale = vel.maxSpeed / speed
        vel.vx = vel.vx * scale
        vel.vy = vel.vy * scale
    end

    -- Energy cost
    local energy = ecs:getComponent(entityId, "Energy")
    if energy and speed > 0.1 then
        energy.value = math.max(0, energy.value - speed * 0.005 * dt)
        -- Slow down if exhausted
        if energy.value <= 0 then
            vel.vx = vel.vx * 0.5
            vel.vy = vel.vy * 0.5
        end
    end

    -- Apply
    local newX = pos.x + vel.vx * dt
    local newY = pos.y + vel.vy * dt

    -- Bounds
    newX = math.max(0, math.min(world.width - 1, newX))
    newY = math.max(0, math.min(world.height - 1, newY))

    -- Walkability
    if world:isWalkable(math.floor(newX), math.floor(newY)) then
        pos.x = newX
        pos.y = newY
    else
        -- Slide along axis
        if world:isWalkable(math.floor(newX), math.floor(pos.y)) then
            pos.x = newX
        elseif world:isWalkable(math.floor(pos.x), math.floor(newY)) then
            pos.y = newY
        end
        vel.vx = vel.vx * 0.5
        vel.vy = vel.vy * 0.5
    end

    -- Friction
    vel.vx = vel.vx * 0.95
    vel.vy = vel.vy * 0.95
    if math.abs(vel.vx) < 0.01 then vel.vx = 0 end
    if math.abs(vel.vy) < 0.01 then vel.vy = 0 end
end

return Movement
