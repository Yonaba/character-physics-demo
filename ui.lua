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

local insert = table.insert
local ipairs = ipairs
local unpack = unpack

-- Mouse hovering
local function mouseIsOn(object)
	local x,y = love.mouse.getPosition()
	return (x > object.x and x < object.x+object.w) 
     and (y > object.y and y < object.y+object.h)
end

-- Internal register
local buttons = {}

-- Button Class Template
local Button = {borderColor = {255,255,0}}
Button.__index = Button

-- Custom Initializer
function Button:new(x,y,w,h)
  local newButton = {}
	newButton.x,newButton.y = x,y
	newButton.w,newButton.h = w,h
	insert(buttons,newButton)
  return setmetatable(newButton, Button)
end

-- Attachs a callback function plus args to a button
function Button:setCallback(f,...)
	self.f = f
	self.arg = {...}
end

-- Runs the attached callback
function Button:callback()
	if self.f then
	self.f(unpack(self.arg))
	end
end

-- Draws a rect border when hovering the button
function Button:drawBorder()
	love.graphics.setColor(self.borderColor)
	love.graphics.rectangle("line",self.x-1,self.y-1,self.w+2,self.h+2)
end

-- Tests if mouse is houvering the button
function Button:mouseIsOn()
	return mouseIsOn(self)
end

-- Draws the button
function Button:draw()	
	if self:mouseIsOn() then 
	self:drawBorder() 
		if love.mouse.isDown("l") and not(self.setPause) then
      self:callback()
      self.setPause = true
		elseif not love.mouse.isDown("l") then
      self.setPause = false
		end
	end
end

-- Callable class
setmetatable(Button, {__call = function(self,...) return self:new(...) end})

-- Wrapping up
return 
	{
		addButton = Button,
		draw = function() 
			for i,element in ipairs(buttons) do
        element:draw()
			end
		end,
	}
