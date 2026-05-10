-- simulation/weather/weather.lua
-- Weather simulation and day/night cycle.

local Config = require("engine.config")

local Weather = {}
Weather.__index = Weather

local WEATHER_TYPES = { "clear", "cloudy", "rain", "storm", "snow", "fog" }

function Weather.new(world)
    local w = setmetatable({}, Weather)
    w.world = world
    w.time = 0
    w.dayLength = Config.DAY_LENGTH
    w.dayTime = 0
    w.dayNumber = 1
    w.isNight = false
    w.current = "clear"
    w.temperature = 22
    w.windSpeed = 2.0
    w.windDir = 0
    w.humidity = 0.5
    w.precipitation = 0
    w.forecast = {}
    w.forecastTimer = 0
    w.forecastInterval = 120
    w.ambientColor = {1,1,1}
    w.lightLevel = 1.0
    w:_generateForecast()
    return w
end

function Weather:update(dt)
    self.time = self.time + dt
    self.dayTime = (self.time % self.dayLength) / self.dayLength
    self.dayNumber = math.floor(self.time / self.dayLength) + 1
    self.isNight = self.dayTime < 0.25 or self.dayTime > 0.75

    -- Lighting
    local t = self.dayTime
    local intensity
    if t < 0.20 then intensity = 0.15
    elseif t < 0.30 then intensity = 0.15 + (t - 0.20) / 0.10 * 0.85
    elseif t < 0.70 then intensity = 1.0 - math.abs(t - 0.50) / 0.20 * 0.15
    elseif t < 0.80 then intensity = 1.0 - (t - 0.70) / 0.10 * 0.85
    else intensity = 0.15 end

    if self.current == "storm" then intensity = intensity * 0.5
    elseif self.current == "rain" then intensity = intensity * 0.7
    elseif self.current == "fog" then intensity = intensity * 0.6
    elseif self.current == "cloudy" then intensity = intensity * 0.85 end
    self.lightLevel = intensity

    if t > 0.25 and t < 0.35 then self.ambientColor = {1.0, 0.75, 0.5}
    elseif t > 0.65 and t < 0.80 then self.ambientColor = {0.95, 0.60, 0.45}
    elseif t < 0.25 or t > 0.80 then self.ambientColor = {0.3, 0.35, 0.6}
    else self.ambientColor = {1,1,1} end

    -- Atmosphere
    self.forecastTimer = self.forecastTimer + dt
    if self.forecastTimer >= self.forecastInterval then
        self.forecastTimer = self.forecastTimer - self.forecastInterval
        self:_advanceForecast()
    end
    self.windDir = self.windDir + (math.random() - 0.5) * 0.1 * dt
    self.windSpeed = math.max(0, self.windSpeed + (math.random() - 0.5) * 0.5 * dt)
    local dayBonus = math.sin(self.dayTime * math.pi) * 8
    local wp = self.current == "snow" and -15 or self.current == "storm" and -5 or self.current == "rain" and -3 or 0
    self.temperature = 20 + dayBonus + wp
    self.precipitation = (self.current == "storm" and 0.9) or (self.current == "snow" and 0.7) or (self.current == "rain" and 0.6) or 0
end

function Weather:_generateForecast()
    self.forecast = {}
    for i = 1, 8 do self.forecast[i] = WEATHER_TYPES[math.random(#WEATHER_TYPES)] end
end

function Weather:_advanceForecast()
    self.current = table.remove(self.forecast, 1) or "clear"
    self.forecast[#self.forecast + 1] = WEATHER_TYPES[math.random(#WEATHER_TYPES)]
end

function Weather:getWeatherAt(x, y) return self.current end
function Weather:getTemperatureAt(x, y)
    local tile = self.world:getTile(x, y)
    return self.temperature - (tile and tile.elevation or 0.5) * 20
end
function Weather:getForecast() return self.forecast end
function Weather:getDayInfo()
    return { day = self.dayNumber, time = self.dayTime, isNight = self.isNight, hour = math.floor(self.dayTime * 24) }
end

function Weather:snapshot()
    return { time = self.time, current = self.current, forecast = self.forecast, windDir = self.windDir, windSpeed = self.windSpeed, dayNumber = self.dayNumber }
end

function Weather:restore(snap)
    self.time = snap.time or 0
    self.current = snap.current or "clear"
    self.forecast = snap.forecast or {}
    self.windDir = snap.windDir or 0
    self.windSpeed = snap.windSpeed or 2
    self.dayNumber = snap.dayNumber or 1
end

return Weather
