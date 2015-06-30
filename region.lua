require 'vector'

Region = {
   identity = "Region class"
}

function Region:new( x, y, size, color )
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   self.size = size
   self.position = Vector:new( x, y )
   self.color = color

   return instance
end

function Region:draw()
   love.graphics.setColor( self.color.r, self.color.g, self.color.b, self.color.a )
   love.graphics.rectangle( 'fill', self.position.x, self.position.y, self.size, self.size )

   love.graphics.origin()
end

function Region:IsInside( position )
   return ( position.x >= self.position.x and position.x <= self.position.x + self.size ) and
      ( position.y >= self.position.y and position.y <= self.position.y + self.size )
end