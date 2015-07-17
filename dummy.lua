require 'vector'
require 'common_functions'

Dummy = {
   identity = "Dummy class",
   radius = 30
}

function Dummy:new( x, y )
   local instance = {}
   setmetatable(instance, self)
   self.__index = self
   
   instance.current_angle = 0.0
   instance.desired_angle = 0.0
   instance.angle_blend = 0.1
   instance.linear_acceleration = 0.03
   instance.last_desired_angle = 0.0
   instance.last_input_angle = 0.0
   instance.current_position = Vector:new( x, y )
   instance.desired_position = Vector:new( x, y )
   instance.current_action = ACTION_None
   instance.desired_action = SUB_ACTION_None
   instance.current_speed = 0.0
   instance.desired_speed = 0.0
   instance.drift_angle = 0.0
   instance.drift_timer = 0.0
   instance.angular_speed_max = 0.1
   instance.angular_acceleration = 0.3
   instance.uturn_timer = 0.0
   instance.last_angular_speed = 0.0
   instance.sight_angle = 0.0
   instance.action_lock = false
   instance.move_type = MOVE_Idle

   return instance
end

function Dummy:Update( dt )
end

function Dummy:GetVelocity()
   return Vector:new( math.cos( self.current_angle ), math.sin( self.current_angle ) )
end

function Dummy:GetMovementDirection()
   return Vector:new( 0.0, 1.0 )
end

function Dummy:DistanceToTarget()
   return ( self.desired_position - self.current_position ):r()
end

function Dummy:DistanceToPosition( position )
   return ( position - self.current_position ):r()
end

function Dummy:draw()
   local angle_in_radian = self.sight_angle
   local pawn_size = 25
   local half_pawn_size = pawn_size * 0.5
   local vertices = 
   {
        half_pawn_size,
        0,
      - half_pawn_size,
        half_pawn_size,
      - half_pawn_size,
      - half_pawn_size
   }
   
   love.graphics.setColor( 255, 0, 255, 255 )
   love.graphics.translate( self.current_position.x, self.current_position.y )
   love.graphics.rotate( angle_in_radian )
   --love.graphics.circle( "fill", half_pawn_size, 0, 5, 100 )

   love.graphics.origin()
end

function Dummy:IsInTrajectoryMode()
  return false
end

function Dummy:GetLastTrajectoryIndex()
    return -1
end
