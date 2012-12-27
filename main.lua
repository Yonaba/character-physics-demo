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
local fps, step_fps, limit_fps, max_fps, low_fps, set_dt, frame_time
local chart_ox, chart_oy = 380, 350
local real_curve

-- Command keys
local KEY_DEC_FPS = 'f'
local KEY_INC_FPS = 'g'
local KEY_JUMP = ' '
local KEY_QUIT = 'escape'
local KEY_MOVE_LEFT = 'left'
local KEY_MOVE_RIGHT = 'right'
local KEY_HIDE_INFO = 'tab'

-- Counts available integrators and their names
-- We'll spawn one agent per integrator
for k,v in pairs(Integrator) do 
  N_players  = N_players + 1
  int_Functions[N_players] = {name = k , func = v}
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

-- Sets the cap value for fps
local function setFps(capped_fps)
    set_dt = 1/capped_fps
    frame_time = love.timer.getMicroTime()
end

-- Clamps a value between min/max bounds
local clamp = function (v, min, max)
  return v < min and min or (v > max and max or v)
end

-- Find the nearest multiple of m starting from n
local nearestMultiple = function (n, m)
  return n + (m - n % m)
end

-- Z-sorting
local sort = function(a,b) return a.height > b.height end
function zSort(agents)
  table.sort(players,sort)
end

-- Draws a legend chart
local draw_legend = function(agents)
  for i = 1, N_players do
    love.graphics.setColor(agents[i].color)
    love.graphics.rectangle('fill',650, 30 + 15 * (i-1), 20, 10)
    love.graphics.print(int_Functions[i].name,690,30 + 15 * (i-1))
  end
end

-- Draws chart
local draw_chart = function(ox, oy)
  love.graphics.setColor(WHITE)
  love.graphics.line(ox, oy, ox, oy-200)
  love.graphics.line(ox, oy, ox + 300, oy)
  love.graphics.line(ox - 300, oy, ox, oy)
end

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
    players[i].height = players[i].height + i * 10 - 35
    players[i].pos:set(40,ground_level - players[i].height)
    players[i].color = color_chart[i]
    -- Attach an unique integrator to each agent
    players[i].integrate = int_Functions[i].func
  end
  
  -- Perform z-sorting, for drawing
  zSort(players)
 
  -- Forces
  F_gravity = Vec(0,300) -- Acceleration, doesn't takes into account the mass
  F_Left = Vec(-100,0) -- Impulse/frame for left move
  F_Right = Vec(100,0) -- Impulse/frame for right move
  F_Up = Vec(0,-300) -- Acts on an agent velocity for the current frame, for jump
  F_damping = 0.9 -- damping factor (varies between 0 and 1)
  
  -- Real curve plot
  real_curve = {}
  
  -- Display command keys control
  showCommands = true
  
  -- FPS control settings
  -- User can set the cap-value beetween 300 and 3.
  low_fps = 3   -- The lowest value
  limit_fps = 300 -- The highest value
  step_fps = 10  -- Step_value
  max_fps = low_fps -- Tracks the current cap value
  setFps(low_fps)  -- Starts at the lowest fps-value
end

function love.update(dt)
  frame_time = frame_time + set_dt
  fps = love.timer.getFPS()
  dt = math.min(dt, set_dt)
  -- Left move
  if love.keyboard.isDown(KEY_MOVE_LEFT) then
    for i = 1,N_players do 
      -- To move agents, give them a constant impulse each frame
      -- as long as the input key is held down
      if players[i]:canJump(ground_level) then 
        players[i]:addForce(F_Left)
      end
    end
  end
  -- Right move
  if love.keyboard.isDown(KEY_MOVE_RIGHT) then
    for i = 1,N_players do
      -- To move agents, give them a constant impulse each frame
      -- as long as the input key is held down
      if players[i]:canJump(ground_level) then
        players[i]:addForce(F_Right)
      end
    end
  end
  -- Jump
  if love.keyboard.isDown(KEY_JUMP) then
    for i = 1,N_players do
      if players[i]:canJump(ground_level) and not players[i].hasJumped then
        -- For jump, we act upon the velocity vector
        -- Only for the actual frame
        players[i]:addVel(F_Up)        
        players[i].hasJumped = true
        
        -- Starts recording parabola for curve plotting
        players[i].trace = true
        players[i].jump_curve = {}
        players[i].jump_curve[1] = players[i].pos.x
        players[i].jump_curve[2] = players[i].pos.y        
      end
    end
    --real_curve = real_integrator(players[1].acc, players[1].vel, players[1].pos)
  end
  
  -- Update agents, wraps them into the window bounds
  for i = 1,N_players do
    players[i]:update(dt, F_gravity, F_damping, ground_level)    
    players[i]:wrap(0,W_W,0,ground_level)
    players[i]:recordCurve(ground_level) -- Curve plot recording
  end

end 

function love.draw()
  -- Draws agents
  
  for i = 1,N_players do
    players[i]:draw(int_Functions[i].name)
    players[i]:plotCurve(chart_ox, chart_oy)
  end
  
  -- Draws ground
  love.graphics.setColor(WHITE)
  love.graphics.line(0,ground_level,W_W,ground_level)
  
  -- Draws chart
  draw_chart(chart_ox, chart_oy)
  
  -- Draws info
  love.graphics.print(('Current : %d FPS'):format(fps),10,10)
  love.graphics.print(('Current limit: %d FPS'):format(max_fps),10,20)
  love.graphics.print(([[Increase/Decrease the FPS Limit using [%s][%s] keys. 
                  FPS Limit will vary between [%d] and [%d] fps]])
    :format(KEY_INC_FPS:upper(), KEY_DEC_FPS:upper(), low_fps, limit_fps),10,40)
  draw_legend(players)
  if showCommands then
    love.graphics.setColor(BROWN)
    love.graphics.rectangle('fill',500,400,250,130)
    love.graphics.setColor(WHITE)
    love.graphics.print([[Command keys:
    
    [F]: Cap down framerate          
    [G]: Cap up framerate
    [Left/Right Arrows]: Move agents
    [Space]: Jump
    [Tab]: Hide/Show command keys
    [Esc]: Quit
    ]],510,410)
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
  if k == KEY_DEC_FPS then
    max_fps = clamp(nearestMultiple(max_fps - step_fps-1,step_fps), low_fps, limit_fps)   
    setFps(max_fps)
  elseif k == KEY_INC_FPS then
    max_fps = clamp(nearestMultiple(max_fps + 1,step_fps), low_fps, limit_fps)   
    setFps(max_fps)
  elseif k == KEY_HIDE_INFO then
    showCommands = not showCommands
  elseif k == KEY_QUIT then
    love.event.push('quit')
  end
end
