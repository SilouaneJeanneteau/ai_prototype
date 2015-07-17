require 'vector'

Region = {
   identity = "Region class"
}

function Region:new( x, y, size, color, new_type )
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   instance.size = size
   instance.position = Vector:new( x, y )
   instance.color = color
   instance.type = new_type

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

function Region:GetType()
    return self.type
end