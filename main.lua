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

-- Requiring depandancies
local Vec = require 'vector'
local Player = require 'player'
local Integrator = require 'integrator'

-- A bit of localizing
local F_damping, F_Left, F_Right, F_Up, F_gravity
local int_Functions = {}
local players
local N_players = 0
local showCommands
local ground_level
local limit_fps, max_fps, low_fps, set_dt, frame_time

-- Counts available integrators and their names
-- We'll spawn one agent per integrator
for k,v in pairs(Integrator) do 
  N_players  = N_players + 1
  int_Functions[N_players] = {name = k , func = v}
end

-- Sets the cap value for fps
local function setFps(capped_fps)
    set_dt = 1/capped_fps
    frame_time = love.timer.getMicroTime()
    print('Capped to ',capped_fps)
end

-- Clamps a value between min/max bounds
local clamp = function (v, min, max)
  return v < min and min or (v > max and max or v)
end

-- Draws a legend chart
local draw_legend = function(agents)
  for i = 1, N_players do
    love.graphics.setColor(agents[i].color)
    love.graphics.rectangle('fill',650, 30 + 15 * (i-1), 20, 10)
    love.graphics.print(int_Functions[i].name,690,30 + 15 * (i-1))
  end
end

-- Some colors
local WHITE = {255,255,255,255}
local BROWN = {150,50,0,155}
local color_chart = {
  {255, 255, 255, 255},
  {0, 255, 255, 255},
  {255, 0, 0, 255},
  {0, 255, 0, 255},
  {0, 0, 255, 255},
  {255, 255, 0, 255},
}

-- Sets the display font size
love.graphics.setFont(love.graphics.newFont(10))


function love.load()

  -- Window size (800x600 by default)
  W_W = love.graphics.getWidth()
  W_H = love.graphics.getHeight()
  ground_level = W_H - 20 -- Ground level
  
  -- Inits some agents
  players = {}
  for i = 1, N_players do
    players[i] = Player()
    players[i].pos:set(40,ground_level - players[i].height)
    players[i].color = color_chart[i]
    -- Attach an unique integrator to each agent
    players[i].integrate = int_Functions[i].func
  end
 
  -- Forces
  F_gravity = Vec(0,300) -- Acceleration, doesn't takes into account the mass
  F_Left = Vec(-100,0) -- Impulse/frame for left move
  F_Right = Vec(100,0) -- Impulse/frame for right move
  F_Up = Vec(0,-300) -- Acts on an agent velocity for the current frame, for jump
  F_damping = 0.5 -- damping factor (varies between 0 and 1)
  
  showCommands = true
  
  -- FPS setting
  -- User can set the cap-value beetween 300 and 3.
  low_fps = 3 
  limit_fps = 300
  max_fps = low_fps
  setFps(max_fps)
end

function love.update(dt)
  frame_time = frame_time + set_dt
  
  -- Left move
  if love.keyboard.isDown('left') then
    for i = 1,N_players do 
      players[i]:addForce(F_Left)
    end
  end
  -- Right move
  if love.keyboard.isDown('right') then
    for i = 1,N_players do   
      players[i]:addForce(F_Right)
    end
  end
  -- Jump
  if love.keyboard.isDown(' ') then    
    for i = 1,N_players do
      if players[i]:canJump(ground_level) and not players[i].hasJumped then      
        players[i]:addVel(F_Up)
        players[i].hasJumped = true
      end
    end
  end
  -- Update, wrap position in the window bounds
  for i = 1,N_players do   
    players[i]:update(dt, F_gravity, F_damping)  
    players[i]:wrap(0,W_W,0,ground_level)
  end      
end 

function love.draw()
  -- Draws agents
  for i = 1,N_players do players[i]:draw() end
  -- Draws ground
  love.graphics.setColor(WHITE)
  love.graphics.line(0,ground_level,W_W,ground_level)
  
  -- Draws info
  love.graphics.print(('FPS/Cap: %d / %d'):format(love.timer.getFPS(), max_fps),10,10)
  draw_legend(players)
  if showCommands then
    love.graphics.setColor(BROWN)
    love.graphics.rectangle('fill',500,300,250,130)
    love.graphics.setColor(WHITE)
    love.graphics.print([[Command keys:
    
    [F]: Cap down framerate          
    [G]: Cap up framerate
    [Left/Right Arrows]: Move agents
    [Space]: Jump
    [Tab]: Hide/Show command keys
    [Esc]: Quit
    ]],510,310)
  end
  
  -- Fps capping
  local this_time = love.timer.getMicroTime()
  if frame_time <= this_time then
    frame_time = this_time
    return
  end
  love.timer.sleep(frame_time - this_time)
end

function love.keyreleased(k, u)
  -- Authorizes a new jump, 
  -- so that agent can't jump again being in the "air".
  if k == ' ' then
    for i = 1,N_players do 
      players[i].hasJumped = false
    end
  end
end

function love.keypressed(k, u)
  -- Command keys
  if k == 'f' then
    max_fps = clamp(max_fps - 10, low_fps, limit_fps)   
    setFps(max_fps)
  elseif k == 'g' then
    max_fps = clamp(max_fps + 10, low_fps, limit_fps)   
    setFps(max_fps)
  elseif k == 'tab' then
    showCommands = not showCommands
  elseif k == 'escape' then
    love.event.push('quit')
  end
end
