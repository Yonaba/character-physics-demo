--[[
  Copyright (c) 2012 Roland Yonaba

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be included
  in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

-- Dependancies
local Vec = require 'vector'
local IEuler = (require 'integrator').IEuler

-- Wraps value between min/max bounds
local wrap = function (v, min, max)
  return v < min and max or (v > max and min or v)
end

-- Clamps value between min/max bounds
local clamp = function (v, min, max, sz)
  sz = sz or 0
  return v < min and min or (v + sz > max and max - sz or v)
end

-- Maximum speed
local vMax = 500

-- Player class
local Player = {}
Player.__index = Player

-- Inits a new player
function Player:new(pos, vel, acc, w, h, mass, int)
  local newPlayer =  {
    pos = pos or Vec(),
    vel = vel or Vec(),
    acc = acc or Vec(),
    width = w or 16,
    height = h or 32,
  }
  newPlayer.mass = mass or 1
  newPlayer.massInv = 1/newPlayer.mass
  newPlayer.sumForces = Vec()
  newPlayer.hasJumped = false
  newPlayer.integrate = int or IEuler -- Default integrator used
  newPlayer.trace = false
  newPlayer.jump_curve = {}
  return setmetatable(newPlayer, Player)
end

-- Adds a force (impulse) for the current frame update
function Player:addForce(f)
  self.sumForces = self.sumForces + f
end

-- Adds velocity
function Player:addVel(v)
  self.vel = self.vel + v
end

-- Updates curve plotting
function Player:recordCurve(axis)
  if self.trace then
    -- Records position each dt for curve plotting
    self.jump_curve[#self.jump_curve+1] = self.pos.x
    self.jump_curve[#self.jump_curve+1] = self.pos.y
  end
  -- Stops recording position
  local touchAxis = (self.pos.y + self.height >= axis)
  if touchAxis then self.trace = false end
end

-- Updates player movement using an integrator
function Player:update(dt, g, damping)
  self:integrate(dt, g, damping, vMax)
end

-- Wraps player into the simulation space
function Player:wrap(left, right, top, bottom)
  local oldx = self.pos.x
  self.pos.x = wrap(self.pos.x, left, right, self.width)  
  self.pos.y = clamp(self.pos.y, top, bottom, self.height)
  -- The plot curve will not be drawn if coordinates were wrapped on x-axis
  if self.pos.x ~= oldx then
    self.trace = false
    self.jump_curve = {}
  end
end

-- Solves resting contact (touching ground level)
-- Checks if the player hits a given ground level
function Player:canJump(ground)
  local isResting = (self.pos.y + self.height >= ground)  
  -- Not true, but that's the trick we need
  if isResting then self.vel.y = 0 end
  return isResting
end

-- Draws the player
function Player:draw()
  love.graphics.setColor(self.color)
  love.graphics.rectangle(
    'fill',
    self.pos.x, self.pos.y, 
    self.width, self.height)
end

-- Plots the jump parabola in the chart local space
function Player:plotCurve(ox, oy)
  -- Make sure we have enough vertices
  if #self.jump_curve > 2 then
    -- Use the initial position to translate 
    -- coordinates into the local space
    local x1 = self.jump_curve[1]
    local y1 = self.jump_curve[2]
    
    -- Alters the transformation stack for curve plotting
    love.graphics.push()
    love.graphics.translate(ox-x1,oy-y1)
    love.graphics.line(self.jump_curve)
    
    -- Restores the transformation stack
    love.graphics.pop()
  end
end    

return setmetatable(Player, 
  {__call = function(self,...) 
    return Player:new(...) 
end})
