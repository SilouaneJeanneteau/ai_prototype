require 'vector'
require 'common_functions'

Boid = {
   identity = "Boid class",
   radius = 30
}

Boid.MAX_SPEED = 100
Boid.MIN_SPEED = 80
Boid.ATTRACTION_RADIUS = Boid.radius * 8
Boid.ATTRACTION_DAMPER = 10
Boid.AVOID_RADIUS = Boid.radius
Boid.AVOID_AMPLIFIER = 2
Boid.ALIGNMENT_RADIUS = Boid.radius * 3
Boid.ALIGNMENT_DAMPER = 8
Boid.HUNTING_RADIUS = Boid.radius * 10
Boid.HUNTING_DAMPER = 5
Boid.STAY_VISIBLE_DAMPER = 40
Boid.FOLLOWING_RADIUS = Boid.radius * 50
Boid.FOLLOWING_AMPLIFIER = 2

Boid.LAST_ANGLE_BOUND = 0.02
Boid.ANGLE_MAX = 0.6
Boid.ANGLE_MAX_2 = 2.0

Boid.MIN_DISTANCE_TO_RECAL = 40.0
Boid.MIN_DISTANCE_TO_IDLE = 5.0
Boid.MIN_ANGLE_DISTANCE = 5.0

Boid.MAX_ANGLE_CONSIDERED_FLAT = 1

function Boid:new( x, y )
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
   instance.movement_direction = Vector:new( 0, 1 )
   instance.locomotion_state = LOCOMOTION_Position
   instance.velocity_delta = Vector:new( 0, 0 )
   instance.trajectory = {}
   instance.trajectory_index = 0
   instance.trajectory_straight_desired_index = 0
   instance.trajectory_is_dirty = true
   instance.start_break_distance = 5.0

   return instance
end

function Boid:Update( dt, other_boids )
   if self.locomotion_state == LOCOMOTION_Position then
       self:ResolveDecision( dt )

       self:ResolveCurrentAction( dt )

       self:CalculateAvoidanceVelocityVector( other_boids )

       self:ResolvePosition( dt )
   elseif self.locomotion_state == LOCOMOTION_Trajectory then
       self:NavigateTrajectory( dt )
   end
end

function Boid:CalculateAvoidanceVelocityVector( boids )
  local new_avoidance_vector = Vector:new( 0, 0 ) 
   for _, other in ipairs( boids ) do
      if self.current_position:isNearby(Boid.AVOID_RADIUS, other.current_position) then
         local avoid_vector = (self.current_position - other.current_position)
         local unit_avoid_accel = avoid_vector:norm()
         local avoid_multiplier = Boid.AVOID_RADIUS * Boid.AVOID_AMPLIFIER / avoid_vector:r()
         local avoid_accel = unit_avoid_accel * avoid_multiplier
         new_avoidance_vector = new_avoidance_vector + avoid_accel
      end
   end

   self.velocity_delta = self.velocity_delta + ( new_avoidance_vector - self.velocity_delta ) * 0.2
end

function Boid:ResolveDecision( dt )
   local delta_x = ( self.desired_position.x - self.current_position.x )
   local delta_y = ( self.desired_position.y - self.current_position.y )

   if math.abs( delta_x ) > 0.001 or math.abs( delta_y ) > 0.001 then
       self.last_input_angle = math.atan2( delta_y, delta_x )
   end

   local delta_angle = WrapAngle( self.last_input_angle - self.sight_angle )
   local abs_delta_angle = math.abs( delta_angle )
   local abs_delta_angle_with_last = math.abs( WrapAngle( self.last_input_angle - self.last_desired_angle ) )

   if abs_delta_angle < Boid.ANGLE_MAX then
      self.desired_action = ACTION_LookFront
   end

   if abs_delta_angle_with_last > Boid.LAST_ANGLE_BOUND then
      self.last_desired_angle = self.last_input_angle

      if abs_delta_angle > Boid.ANGLE_MAX_2 then
         self.desired_action = ACTION_GoBack
      elseif abs_delta_angle > Boid.ANGLE_MAX then
         self.desired_action = ACTION_Turn
      end
   end

   if not self.action_lock then
      if self.desired_action == ACTION_Turn then
         if delta_angle > 0.0 then
            self.current_action = SUB_ACTION_RightTurn
         else
            self.current_action = SUB_ACTION_LeftTurn
         end
      elseif self.desired_action == ACTION_LookFront then
         self.current_action = SUB_ACTION_LookFront
      elseif self.desired_action == ACTION_GoBack then
         if self.current_speed < 1.0 then
            self.current_action = SUB_ACTION_UTurn
         else
            self.drift_angle = self.current_angle

            if self.current_speed > -1.0 and self.current_speed < 6.0 then
               self.current_action = SUB_ACTION_DriftUTurn
            else
               self.current_action = SUB_ACTION_BigDriftUTurn
            end
         end

         self.action_lock = true
      end
   end
end

function Boid:ResolveCurrentAction( dt )
   if self.current_action == SUB_ACTION_LookFront or self.current_action == SUB_ACTION_RightTurn or self.current_action == SUB_ACTION_LeftTurn then
      if self.move_type == MOVE_Idle then
         self.desired_speed = 0.0
         self.angular_speed_max = 0.07
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.2 --0.6
      elseif self.move_type == MOVE_SlowWalk then
         self.desired_speed = 1.0
         self.angular_speed_max = 0.1
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.08
      elseif self.move_type == MOVE_Walk then
         self.desired_speed = 3.0
         self.angular_speed_max = 0.1
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.05
      elseif self.move_type == MOVE_FastWalk then
         self.desired_speed = 5.0
         self.angular_speed_max = 0.1
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.02
      elseif self.move_type == MOVE_Run then
         self.desired_speed = 10.0
         self.angular_speed_max = 0.2
         self.angular_acceleration = 0.15
         self.linear_acceleration = 0.01
      elseif self.move_type == MOVE_Recal then
         self.desired_speed = 1.0
         self.angular_speed_max = 0.5
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.5
      elseif self.move_type == MOVE_Aim then
         self.desired_speed = 0.0
         self.angular_speed_max = 0.07
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.2
      end

      self.desired_angle = self.last_input_angle
   elseif self.current_action == SUB_ACTION_DriftUTurn then
      self.desired_speed = -1.0
      self.angular_speed_max = 0.01
      self.angle_blend = 0.1
      self.angular_acceleration = 0.2
      self.desired_angle = self.last_input_angle
      self.drift_timer = self.drift_timer + dt

      if self.drift_timer > 0.3 then
         self.drift_timer = 0.0
         self.current_action = SUB_ACTION_UTurn
      end
   elseif self.current_action == SUB_ACTION_BigDriftUTurn then
      self.desired_speed = -3.0
      self.angular_speed_max = 0.01
      self.angle_blend = 0.1
      self.angular_acceleration = 0.2
      self.desired_angle = self.drift_angle
      self.drift_timer = self.drift_timer + dt

      if self.drift_timer > 0.4 then
         self.drift_timer = 0.0
         self.current_action = SUB_ACTION_UTurn
      end
   elseif self.current_action == SUB_ACTION_UTurn then
      if self.move_type == MOVE_Idle then
         self.desired_speed = 0.0
         self.angular_speed_max = 0.2
         self.angular_acceleration = 0.1
         self.angle_blend = 0.2
      elseif self.move_type == MOVE_SlowWalk then
         self.desired_speed = 0.0
         self.angular_speed_max = 0.01
         self.angular_acceleration = 0.2
         self.angle_blend = 0.2
      elseif self.move_type == MOVE_Walk or self.move_type == MOVE_FastWalk then
         self.desired_speed = 0.0
         self.angular_speed_max = 0.2
         self.angular_acceleration = 0.2
         self.angle_blend = 0.2
      elseif self.move_type == MOVE_Run then
         self.desired_speed = 0.0
         self.angular_speed_max = 0.2
         self.angular_acceleration = 0.1
         self.angle_blend = 0.2
      elseif self.move_type == MOVE_Recal then
         self.desired_speed = 1.0
         self.angular_speed_max = 0.5
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.3
      elseif self.move_type == MOVE_Aim then
         self.desired_speed = 0.0
         self.angular_speed_max = 0.2
         self.angular_acceleration = 0.1
         self.angle_blend = 0.2
      end

      self.desired_angle = self.last_input_angle
      self.uturn_timer = self.uturn_timer + dt

      if self.uturn_timer > 0.5 then
         self.action_lock = false
         self.uturn_timer = 0.0
      end
   end
end

function Boid:ResolvePosition( dt )
   if self.move_type ~= MOVE_Idle then
       local current_delta_angle = WrapAngle( self.desired_angle - self.current_angle )
       local abs_current_delta_angle = math.abs( current_delta_angle )
       local angle_speed_dest = 0.0
       local smoothing_factor = ( 1.0 / self.angular_acceleration )

       if abs_current_delta_angle > 0.00001 then
          local delta_angle_sign = ( abs_current_delta_angle / current_delta_angle )
          angle_speed_dest = current_delta_angle * smoothing_factor * dt

          if math.abs( angle_speed_dest ) > self.angular_speed_max then
             angle_speed_dest = self.angular_speed_max * delta_angle_sign
          end
       end

       self.last_angular_speed = self.last_angular_speed + WrapAngle( angle_speed_dest - self.last_angular_speed ) * smoothing_factor * dt

       if math.abs( self.last_angular_speed ) > abs_current_delta_angle then
          self.last_angular_speed = current_delta_angle
       end

       self.current_angle = WrapAngle( self.current_angle + self.last_angular_speed )
       local angle_sight_speed = WrapAngle( self.current_angle - self.sight_angle ) * self.angle_blend
       self.sight_angle = WrapAngle( angle_sight_speed + self.sight_angle )
   end
   
   self.current_speed = self.current_speed + ( self.desired_speed - self.current_speed ) * self.linear_acceleration

   local old_position = self.current_position
   local movement_direction
   
   if self.move_type == MOVE_Recal then
       movement_direction = ( self.desired_position - self.current_position ):norm()
   else
       movement_direction = Vector:new( math.cos( self.current_angle ), math.sin( self.current_angle ) ) + self.velocity_delta
   end

   self.current_position = self.current_position + movement_direction * self.current_speed

   self.velocity_delta = Vector:new( 0, 0 )

   if math.abs( self.current_speed ) > 0.5 then
      self.movement_direction = ( self.current_position - old_position ):norm()
   end
end

function Boid:GetVelocity()
   return Vector:new( math.cos( self.current_angle ), math.sin( self.current_angle ) )
end

function Boid:GetMovementDirection()
   return self.movement_direction
end

function Boid:DistanceToTarget()
   return ( self.desired_position - self.current_position ):r()
end

function Boid:DistanceToPosition( position )
   return ( position - self.current_position ):r()
end

function Boid:GoTo( position, move_type )
   self.desired_position = position
   self.move_type = move_type
end

function Boid:Stop()
   self.desired_position = self.current_position
   self.move_type = MOVE_Idle
end

function Boid:StopNow()
    self:Stop()
    self.current_speed = 0.0
    self.desired_speed = 0.0
    self.drift_angle = 0.0
    self.drift_timer = 0.0
    self.uturn_timer = 0.0
    self.current_action = SUB_ACTION_LookFront
end

function Boid:StopSoftly()
    self:Stop()
    self.desired_speed = 0.0
    self.drift_angle = 0.0
    self.drift_timer = 0.0
    self.uturn_timer = 0.0
    self.linear_acceleration = 1.0
    self.current_action = SUB_ACTION_LookFront
end

function Boid:ChangeLocomotion( locomotion )
    self.locomotion_state = locomotion
end

function Boid:AddToTrajectory( point )
    table.insert( self.trajectory, point )
    self.trajectory_is_dirty = true
end

function Boid:ResetTrajectory()
    self.trajectory = {}
    self.trajectory_index = 0
    self.trajectory_straight_desired_index = 0
    self.trajectory_is_dirty = true
end

function Boid:draw( i )
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
   
   love.graphics.setColor( 255, 255, 255, 255 )
   love.graphics.translate( self.current_position.x, self.current_position.y )
   love.graphics.rotate( angle_in_radian )
   love.graphics.polygon( 'fill', vertices )

   love.graphics.origin()
   
   love.graphics.setColor( 255, 0, 0, 255 )
   love.graphics.translate( self.current_position.x, self.current_position.y )
   love.graphics.rotate( angle_in_radian )
   love.graphics.circle( "fill", half_pawn_size, 0, 5, 100 )

   love.graphics.origin()
   
   love.graphics.setColor( 0, 0, 0, 255 )
   love.graphics.translate( self.current_position.x, self.current_position.y )
   love.graphics.print( i, 0, 0, 0, 2, 2 )

   love.graphics.origin()
end

function Boid:NavigateTrajectory( dt )    
    if self.trajectory_index < #self.trajectory then
        self.desired_position = self.trajectory[ self.trajectory_index + 1 ]
        local current_to_target_vector = self.desired_position - self.current_position
        local speed = current_to_target_vector:r()
        speed = 200
        self.current_position = self.current_position + current_to_target_vector:norm() * speed * dt
        
        self.current_angle = current_to_target_vector:ang() - 90 * math.pi / 180
        local angle_sight_speed = WrapAngle( self.current_angle - self.sight_angle ) * self.angle_blend
        self.sight_angle = WrapAngle( angle_sight_speed + self.sight_angle )
        
        if ( self.current_position - self.desired_position ):r() < 5.0 then
            self.trajectory_index = self.trajectory_index + 1
        end
    end
end

function Boid:UpdateStraightPath( dt )
    local straight_index_has_changed = false
    if self.trajectory_straight_desired_index < #self.trajectory and self.trajectory_is_dirty then
        local first_direction
        local samed_direction_trajectory_index
        
        if self.trajectory_straight_desired_index == 1 then
            first_direction = ( self.trajectory[ self.trajectory_straight_desired_index ] - self.trajectory[ self.trajectory_straight_desired_index + 1 ] ):norm()
            samed_direction_trajectory_index = self.trajectory_straight_desired_index + 1
        else
            first_direction = ( self.trajectory[ self.trajectory_straight_desired_index - 1 ] - self.trajectory[ self.trajectory_straight_desired_index ] ):norm()
            samed_direction_trajectory_index = self.trajectory_straight_desired_index
        end
        
        for index = samed_direction_trajectory_index, #self.trajectory - 1 do
            local current_direction = ( self.trajectory[ index ] - self.trajectory[ index + 1 ] ):norm()
            local current_angle = math.acos( ( first_direction:dot( current_direction ) ) / ( first_direction:r() * current_direction:r() ) )
            
            if current_angle <= ( Boid.MAX_ANGLE_CONSIDERED_FLAT * math.pi / 180 ) then
                self.trajectory_straight_desired_index = index + 1
                straight_index_has_changed = true
            end
        end
        
        self.trajectory_is_dirty = false
    end
    
    return straight_index_has_changed
end

function Boid:IsInTrajectoryMode()
  return self.locomotion_state == LOCOMOTION_Trajectory
end


