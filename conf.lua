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

function love.conf(t)
  t.title = "Physics-based movement & Jump (Demo)"
  t.author = "Roland_Yonaba"
  t.url = "https://github.com/Yonaba/character-physics-demo"
  t.version = "0.9.0"
  t.console = false
  t.window.width = 800
  t.window.height = 600
  t.window.fullscreen = false
  t.window.vsync = false
  t.window.fsaa = 0
  t.modules.joystick = false
  t.modules.audio = false
  t.modules.mouse = true
  t.modules.sound = false
  t.modules.physics = false 
end