require 'vector'

Bait = {
   identity = "Bait class",
   radius = 2.5
}

function Bait:new( x, y )
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   instance:spawn( x, y )
   return instance
end

function Bait:spawn( x, y )
   if x == nil then
      x = love.graphics.getWidth() * math.random()
   end
   if y == nil then
      y = love.graphics.getHeight() * math.random()
   end
   self.size = Bait.radius * 2
   self.position = Vector:new( x, y )
end

function Bait:isEaten( boid )
   return self.position:isNearby( Bait.radius * 5, boid.position )
end

function Bait:draw()
   love.graphics.setColor( 0, 0, 255, 255 )
   love.graphics.translate( self.position.x, self.position.y )
   love.graphics.circle( "fill", 0, 0, self.size, 100 )

   love.graphics.origin()
end
