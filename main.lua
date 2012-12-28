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
local Ui = require 'ui'

-- Initializing some vars
local F_damping, F_Left, F_Right, F_Up, F_gravity
local int_Functions = {}
local players
local showCommands
local ground_level
local fps, step_fps, limit_fps, max_fps, low_fps, step_dt, frame_time
local real_curve, real_curve_area, real_peak, real_range
local N_players = 0
local chart_ox, chart_oy = 260, 310

-- Command keys
local KEY_DEC_FPS = 'f'
local KEY_INC_FPS = 'g'
local KEY_JUMP = ' '
local KEY_QUIT = 'escape'
local KEY_MOVE_LEFT = 'left'
local KEY_MOVE_RIGHT = 'right'
local KEY_HIDE_INFO = 'tab'

-- Counts all available integrators and their names
-- We'll spawn one agent per integrator
for k,v in pairs(Integrator) do
  -- Counts available integrators
  N_players  = N_players + 1
  
  -- Keep track of some metrics
  int_Functions[N_players] = {
    name = k , func = v,
    acc = 0, vel = 0 ,
    jump_peak = 0, jump_range = 0, accuracy = 0,
    show = true} 
end

-- Some hidden buttons to hide/unhide some agents and their stats
for i = 1, N_players do
  local button = Ui.addButton(350, 30 + 15 * i, 20, 10 )  
  button:setCallback(function()
    int_Functions[i].show = not int_Functions[i].show
  end)
end  

-- Some colors
local WHITE = {255, 255, 255, 255}
local BROWN = {150, 050, 000, 155}
local CBLUE  = {000, 200, 255, 255}
local GREY   = {100, 100, 155, 255}
local color_chart = {
  {255, 255, 255, 255},
  {000, 255, 255, 255},
  {255, 000, 000, 255},
  {000, 255, 000, 255},
  {000, 000, 255, 255},
  {255, 255, 000, 255},
}

-- Sets the cap-value for framerate
local function setFps(capped_fps)
    step_dt = 1/capped_fps
    frame_time = love.timer.getMicroTime()
end

-- Clamps a value between min/max bounds
local clamp = function (v, min, max)
  return v < min and min or (v > max and max or v)
end

-- Find the nearest multiple of m near n
local nearestMultiple = function (n, m)
  return n + (m - n % m)
end

-- Draws the chart legend
local draw_legend = function(agents)
  local x = 350
  
  -- Headers
  love.graphics.printf('Accel',x+80,15,60,'right')
  love.graphics.printf('Vel',x+140,15,60,'right')
  love.graphics.printf('Jmp peak',x+200,15,60,'right')
  love.graphics.printf('Jmp range',x+260,15,60,'right')
  love.graphics.printf('Accur',x+320,15,60,'right')
  
  -- Real curve legend
  love.graphics.setColor(CBLUE)
  love.graphics.rectangle('fill',x, 30, 20, 10)
  love.graphics.print('Real',x+40,30)
  love.graphics.printf(('%.1f'):format(int_Functions[1].acc),x+80,30,60,'right')
  love.graphics.printf(('%.1f'):format(int_Functions[1].vel),x+140,30,60,'right')
  love.graphics.printf(('%.1f'):format(real_peak),x+200,30,60,'right')
  love.graphics.printf(('%.1f'):format(real_range),x+260,30,60,'right')
  love.graphics.printf('---',x+320,30,60,'right')  
  
  -- Integrators, names and accuracies
  for i = 1, #int_Functions do
    if int_Functions[i].show then
      love.graphics.setColor(agents[i].color)
      love.graphics.rectangle('fill',x, 30 + 15 * i, 20, 10)    
      love.graphics.print(('%s'):format(int_Functions[i].name),x+40,30 + 15 * i)      
      love.graphics.printf(('%.1f'):format(int_Functions[i].acc),x+80,30 + 15 * i,60,'right')
      love.graphics.printf(('%.1f'):format(int_Functions[i].vel),x+140,30 + 15 * i,60,'right')
      love.graphics.printf(('%.1f'):format(int_Functions[i].jump_peak),x+200,30 + 15 * i,60,'right')
      love.graphics.printf(('%.1f'):format(int_Functions[i].jump_range),x+260,30 + 15 * i,60,'right')
      love.graphics.printf(('%.1f%%'):format(int_Functions[i].accuracy),x+320,30 + 15 * i,60,'right')
    else
      love.graphics.setColor(GREY)
      love.graphics.rectangle('fill',x, 30 + 15 * i, 20, 10)      
    end    
  end
end

-- Draws chart
local draw_chart = function(ox, oy, lenx, leny)
  lenx = lenx or 250
  leny = leny or 150
  love.graphics.setColor(WHITE)
  love.graphics.line(ox, oy, ox, oy-leny)
  love.graphics.line(ox, oy, ox + lenx, oy)
  love.graphics.line(ox - lenx, oy, ox, oy)
end

-- Real integration
local acos = math.acos
local cos, sin, tan = math.cos, math.sin, math.tan
local ceil, min = math.ceil, math.min
local real_integration = function(a, v, ox, oy)
  local curve = {ox, oy} -- Curve
  local t = 0  -- time counter
  local dt = 1/30  -- fixed timestep
  
  local v0 = v:mag()  -- initial speed
  local a0 = a:mag() -- initial speed
  local theta = acos(v.x / v0) -- jump angle   
  local cost = cos(theta)
  local tant = tan(theta)
  local sint = sin(theta)
  
  local d = 2 * v0 * sint / a0 -- jump duration
  local samps = ceil(d/dt) -- number of timesteps to reach the jump duration
  
  -- Calculates the curve
  for i = 1,samps do
    t = t + dt
    local x = v0 * cost * t    
    local tj = x/(v0 * cost)
    local y = 0.5 * a0 * tj * tj - (x * tant)
    local crossAxis = y > 0
    curve[#curve+1] = x + ox
    curve[#curve+1] = min(y,0) + oy
    if crossAxis then break end -- exit condition, when we cross the horizontal axis
  end
 
  return curve
end

-- Real curve plot
function plotCurve(c, ox, oy, color)
  -- Make sure we have enough vertices
  if #c > 2 then
    love.graphics.setLineWidth(2)
    love.graphics.setColor(color)
    love.graphics.line(c)
  end
end

-- Evaluates shadowed area, peak and range from a given jump curve
local max = math.max
local tArea = function(b1, b2, h) return (b1 + b2) * (h / 2) end
local evalStats = function(oy, curve)
  local area = 0
  local peak = 0
  local range = 0
  local nPoints = (#curve / 2)
  local i = 0
  for step = 1, nPoints-1 do
    i = i + 2
    local b1 = (oy - curve[i])
    local b2 = (oy - curve[i+2])
    local h = (curve[i+1] - curve[i-1]) 
    peak = max(peak, max(b1, b2))
    range = range + h
    area = area + tArea(b1, b2, h)
  end
  return area, peak, range
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
    players[i].height = players[i].height + 25 - (i-1) * 10
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
  F_damping = 0.9 -- damping factor (varies between 0 and 1)
  
  -- Real curve & stats
  real_curve = {}
  real_peak = 0
  real_range = 0
  
  -- Display command keys control
  showCommands = true
  
  -- FPS control settings
  -- User can set the cap-value beetween 300 and 3.
  low_fps = 3   -- The lowest value
  limit_fps = 300 -- The highest value
  step_fps = 5  -- Step_value
  max_fps = 30 -- Tracks the current cap value
  setFps(max_fps)  -- Starts at the lowest fps-value
end

function love.update(dt)
  -- Step dt
  frame_time = frame_time + step_dt
  fps = love.timer.getFPS()
  
  -- Let's make sure we're not updating with any dt higher than step_dt
  dt = min(dt, step_dt)
  
  -- Left move
  if love.keyboard.isDown(KEY_MOVE_LEFT) then
    for i = 1,N_players do 
      -- To move agents, give them a constant impulse each frame
      -- as long as the input key is held down
      if players[i]:isOnGround(ground_level) then 
        players[i]:addForce(F_Left)
      end
    end
  end
  
  -- Right move
  if love.keyboard.isDown(KEY_MOVE_RIGHT) then
    for i = 1,N_players do
      -- To move agents, give them a constant impulse each frame
      -- as long as the input key is held down
      if players[i]:isOnGround(ground_level) then
        players[i]:addForce(F_Right)
      end
    end
  end
  
  -- Jump
  if love.keyboard.isDown(KEY_JUMP) then
    for i = 1,N_players do
     if players[i]:isOnGround(ground_level) and not players[i].hasJumped then
        -- For jump, we act upon the velocity vector
        -- Only for the actual frame
        players[i]:addVel(F_Up)        
        players[i].hasJumped = true
        
        -- Starts recording parabola for curve plotting
        players[i].trace = true
        players[i].jump_curve = {}
        players[i].jump_curve[1] = players[i].pos.x
        players[i].jump_curve[2] = players[i].pos.y
        
        -- Evaluates the real jump curve & stats
        if i==1 then 
          real_curve = real_integration(players[i].acc, players[i].vel:clamp(players[i].vMax), chart_ox, chart_oy)
          real_curve_area, real_peak, real_range = evalStats(chart_oy, real_curve)
        end        
      end
    end    
  end
    
  -- Update agents, wraps them into the window bounds
  for i = 1,N_players do
    players[i]:update(dt, F_gravity, F_damping, ground_level)    
    players[i]:wrap(0,W_W,0,ground_level)
    players[i]:recordCurve(ground_level) -- keep tracing the jump curve
    
    -- Evaluates stats from all integrators jump curve
    int_Functions[i].acc = players[i].acc:mag()
    int_Functions[i].vel = players[i].vel:mag()    
    if not players[i].trace and #players[i].jump_curve > 0 then
      if real_curve_area > 0 then
        local area, peak, range = evalStats(players[i].jump_curve[2], players[i].jump_curve)
        int_Functions[i].accuracy = (area * 100) /real_curve_area
        int_Functions[i].jump_peak = peak
        int_Functions[i].jump_range = range
      end
    end
  end
end 

function love.draw()
  
  -- Draws agents
  love.graphics.setLineWidth(1)
  for i = 1,N_players do
    if int_Functions[i].show then
      players[i]:draw(int_Functions[i].name)
      players[i]:plotCurve(chart_ox, chart_oy)
    end
  end
  
  -- Draws ground
  love.graphics.setColor(WHITE)
  love.graphics.line(0, ground_level, W_W, ground_level)
  
  -- Draws chart
  draw_chart(chart_ox, chart_oy)
  
  -- Plot Real curve
  plotCurve(real_curve, chart_ox, chart_ox, CBLUE)
  
  -- Draws info
  love.graphics.setColor(WHITE)
  love.graphics.print(('Current : %d FPS'):format(fps),10,10)
  love.graphics.print(('Current limit: %d FPS'):format(max_fps),10,25)
  love.graphics.print(('FPS Cap varies between [%d] and [%d] fps by steps of [%d] fps')
    :format(low_fps, limit_fps, step_fps),10,40)
  
  -- Draws legend
  draw_legend(players)
  
  -- Draws Ui
  Ui.draw()  
  
  -- Prints command keys
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
    [LMB] (On Chart): Show/Hide an agent
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
