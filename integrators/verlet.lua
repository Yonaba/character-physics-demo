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

-- Integration
-- p(t+dt) = p(t) + dt*v(t)+ 0.5*dt*dt*a(t)
-- v(t+dt) = v(t) + (a(t) + a(t+dt))*0.5*dt
-- i.e v(t+dt) = v(t) + (a(t))*dt, as a(t) is constant
function Verlet(agent, dt, g, damping, vmax)
  agent.sumForces = agent.sumForces + (g * agent.mass)
  agent.acc = agent.sumForces * agent.massInv
  agent.pos = agent.pos + agent.vel * dt + agent.acc * (dt * dt * 0.5)
  agent.vel = (agent.vel + agent.acc * dt) * (damping ^ dt)
  agent.vel:clamp(vmax)
  agent.sumForces:clear()
end

return Verlet