require 'vector'
require 'common_functions'

Boid = {
   identity = "Boid class",
   radius = 30
}

Boid.AVOID_RADIUS = Boid.radius
Boid.AVOID_AMPLIFIER = 2

Boid.LAST_ANGLE_BOUND = 0.02
Boid.ANGLE_MAX = 0.6
Boid.ANGLE_MAX_2 = 2.0

Boid.MIN_DISTANCE_TO_RECAL = 40.0
Boid.MIN_DISTANCE_TO_IDLE = 5.0
Boid.MIN_ANGLE_DISTANCE = 5.0

Boid.MAX_ANGLE_CONSIDERED_FLAT = 1

Boid.MAX_DISTANCE_TO_TRAJECTORY_SLOT = 5.0

-- Capacity parameters
-- FAST
Boid.FAST_POSITION_LINEAR_VERY_SLOW_SPEED = 60.0
Boid.FAST_POSITION_LINEAR_SLOW_SPEED = 180.0
Boid.FAST_POSITION_LINEAR_NORMAL_SPEED = 300.0
Boid.FAST_POSITION_LINEAR_FAST_SPEED = 600.0
Boid.FAST_POSITION_LINEAR_RECAL_SPEED = 60.0

Boid.FAST_MAX_ANGLE_TO_STOP = 40.0
Boid.FAST_MAX_ANGLE_TO_VERY_SLOW = 30.0
Boid.FAST_MAX_ANGLE_TO_SLOW = 15.0

Boid.FAST_TRAJECTORY_LINEAR_VERY_SLOW_SPEED = 60.0
Boid.FAST_TRAJECTORY_LINEAR_SLOW_SPEED = 100.0
Boid.FAST_TRAJECTORY_LINEAR_NORMAL_SPEED = 180.0

Boid.FAST_TRAJECTORY_ANGULAR_VERY_SLOW_SPEED = 0.2
Boid.FAST_TRAJECTORY_ANGULAR_SLOW_SPEED = 0.2
Boid.FAST_TRAJECTORY_ANGULAR_NORMAL_SPEED = 0.2

Boid.FAST_TRAJECTORY_VERY_SLOW_POINT_COUNT = 2
Boid.FAST_TRAJECTORY_SLOW_POINT_COUNT = 2

Boid.FAST_TRAJECTROY_MINIMUM_SLOT_TO_DETECT_LEADER = 10
Boid.FAST_TRAJECTROY_JOIN_LEADER_ACCELERATION = 0.05

-- SLOW
Boid.SLOW_POSITION_LINEAR_VERY_SLOW_SPEED = 20.0
Boid.SLOW_POSITION_LINEAR_SLOW_SPEED = 80.0
Boid.SLOW_POSITION_LINEAR_NORMAL_SPEED = 90.0
Boid.SLOW_POSITION_LINEAR_FAST_SPEED = 100.0
Boid.SLOW_POSITION_LINEAR_RECAL_SPEED = 20.0

Boid.SLOW_MAX_ANGLE_TO_STOP = 40.0
Boid.SLOW_MAX_ANGLE_TO_VERY_SLOW = 15.0
Boid.SLOW_MAX_ANGLE_TO_SLOW = 5.0

Boid.SLOW_TRAJECTORY_LINEAR_VERY_SLOW_SPEED = 20.0
Boid.SLOW_TRAJECTORY_LINEAR_SLOW_SPEED = 50.0
Boid.SLOW_TRAJECTORY_LINEAR_NORMAL_SPEED = 80.0

Boid.SLOW_TRAJECTORY_ANGULAR_VERY_SLOW_SPEED = 0.07
Boid.SLOW_TRAJECTORY_ANGULAR_SLOW_SPEED = 0.08
Boid.SLOW_TRAJECTORY_ANGULAR_NORMAL_SPEED = 0.2

Boid.SLOW_TRAJECTORY_VERY_SLOW_POINT_COUNT = 2
Boid.SLOW_TRAJECTORY_SLOW_POINT_COUNT = 3

Boid.SLOW_TRAJECTROY_MINIMUM_SLOT_TO_DETECT_LEADER = 10
Boid.SLOW_TRAJECTROY_JOIN_LEADER_ACCELERATION = 0.05
-------

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
   instance.trajectory_last_index_processed = 0
   instance.trajectory_last_index = 0
   instance.trajectory_leader = nil
   instance.trajectory_follows = true
   
   instance:SetCapacityToFast()

   return instance
end

function Boid:SetCapacityToFast()
   self.POSITION_LINEAR_VERY_SLOW_SPEED = Boid.FAST_POSITION_LINEAR_VERY_SLOW_SPEED
   self.POSITION_LINEAR_SLOW_SPEED = Boid.FAST_POSITION_LINEAR_SLOW_SPEED
   self.POSITION_LINEAR_NORMAL_SPEED = Boid.FAST_POSITION_LINEAR_NORMAL_SPEED
   self.POSITION_LINEAR_FAST_SPEED = Boid.FAST_POSITION_LINEAR_FAST_SPEED
   self.POSITION_LINEAR_RECAL_SPEED = Boid.FAST_POSITION_LINEAR_RECAL_SPEED

   self.MAX_ANGLE_TO_STOP = Boid.FAST_MAX_ANGLE_TO_STOP
   self.MAX_ANGLE_TO_VERY_SLOW = Boid.FAST_MAX_ANGLE_TO_VERY_SLOW
   self.MAX_ANGLE_TO_SLOW = Boid.FAST_MAX_ANGLE_TO_SLOW

   self.TRAJECTORY_LINEAR_VERY_SLOW_SPEED = Boid.FAST_TRAJECTORY_LINEAR_VERY_SLOW_SPEED
   self.TRAJECTORY_LINEAR_SLOW_SPEED = Boid.FAST_TRAJECTORY_LINEAR_SLOW_SPEED
   self.TRAJECTORY_LINEAR_NORMAL_SPEED = Boid.FAST_TRAJECTORY_LINEAR_NORMAL_SPEED

   self.TRAJECTORY_ANGULAR_VERY_SLOW_SPEED = Boid.FAST_TRAJECTORY_ANGULAR_VERY_SLOW_SPEED
   self.TRAJECTORY_ANGULAR_SLOW_SPEED = Boid.FAST_TRAJECTORY_ANGULAR_SLOW_SPEED
   self.TRAJECTORY_ANGULAR_NORMAL_SPEED = Boid.FAST_TRAJECTORY_ANGULAR_NORMAL_SPEED

   self.TRAJECTORY_VERY_SLOW_POINT_COUNT = Boid.FAST_TRAJECTORY_VERY_SLOW_POINT_COUNT
   self.TRAJECTORY_SLOW_POINT_COUNT = Boid.FAST_TRAJECTORY_SLOW_POINT_COUNT
   
   self.TRAJECTROY_MINIMUM_SLOT_TO_DETECT_LEADER = Boid.FAST_TRAJECTROY_MINIMUM_SLOT_TO_DETECT_LEADER
   self.TRAJECTROY_JOIN_LEADER_ACCELERATION = Boid.FAST_TRAJECTROY_JOIN_LEADER_ACCELERATION
end

function Boid:SetCapacityToSlow()
   self.POSITION_LINEAR_VERY_SLOW_SPEED = Boid.SLOW_POSITION_LINEAR_VERY_SLOW_SPEED
   self.POSITION_LINEAR_SLOW_SPEED = Boid.SLOW_POSITION_LINEAR_SLOW_SPEED
   self.POSITION_LINEAR_NORMAL_SPEED = Boid.SLOW_POSITION_LINEAR_NORMAL_SPEED
   self.POSITION_LINEAR_FAST_SPEED = Boid.SLOW_POSITION_LINEAR_FAST_SPEED
   self.POSITION_LINEAR_RECAL_SPEED = Boid.SLOW_POSITION_LINEAR_RECAL_SPEED

   self.MAX_ANGLE_TO_STOP = Boid.SLOW_MAX_ANGLE_TO_STOP
   self.MAX_ANGLE_TO_VERY_SLOW = Boid.SLOW_MAX_ANGLE_TO_VERY_SLOW
   self.MAX_ANGLE_TO_SLOW = Boid.SLOW_MAX_ANGLE_TO_SLOW

   self.TRAJECTORY_LINEAR_VERY_SLOW_SPEED = Boid.SLOW_TRAJECTORY_LINEAR_VERY_SLOW_SPEED
   self.TRAJECTORY_LINEAR_SLOW_SPEED = Boid.SLOW_TRAJECTORY_LINEAR_SLOW_SPEED
   self.TRAJECTORY_LINEAR_NORMAL_SPEED = Boid.SLOW_TRAJECTORY_LINEAR_NORMAL_SPEED

   self.TRAJECTORY_ANGULAR_VERY_SLOW_SPEED = Boid.SLOW_TRAJECTORY_ANGULAR_VERY_SLOW_SPEED
   self.TRAJECTORY_ANGULAR_SLOW_SPEED = Boid.SLOW_TRAJECTORY_ANGULAR_SLOW_SPEED
   self.TRAJECTORY_ANGULAR_NORMAL_SPEED = Boid.SLOW_TRAJECTORY_ANGULAR_NORMAL_SPEED

   self.TRAJECTORY_VERY_SLOW_POINT_COUNT = Boid.SLOW_TRAJECTORY_VERY_SLOW_POINT_COUNT
   self.TRAJECTORY_SLOW_POINT_COUNT = Boid.SLOW_TRAJECTORY_SLOW_POINT_COUNT
   
   self.TRAJECTROY_MINIMUM_SLOT_TO_DETECT_LEADER = Boid.SLOW_TRAJECTROY_MINIMUM_SLOT_TO_DETECT_LEADER
   self.TRAJECTROY_JOIN_LEADER_ACCELERATION = Boid.SLOW_TRAJECTROY_JOIN_LEADER_ACCELERATION
end

function Boid:Update( dt, other_boids )
    if self.locomotion_state == LOCOMOTION_Position then
        self:ResolveDecision( dt )

        self:ResolveCurrentAction( dt )

        self:CalculateAvoidanceVelocityVector( other_boids )

        self:ResolvePosition( dt )
    elseif self.locomotion_state == LOCOMOTION_Trajectory then
        self:UpdateTrajectoryProcessing( dt )
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
         if self.current_speed < 60.0 then
            self.current_action = SUB_ACTION_UTurn
         else
            self.drift_angle = self.current_angle

            if self.current_speed > -60.0 and self.current_speed < 360.0 then
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
         self.desired_speed = self.POSITION_LINEAR_VERY_SLOW_SPEED
         self.angular_speed_max = 0.1
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.08
      elseif self.move_type == MOVE_Walk then
         self.desired_speed = self.POSITION_LINEAR_SLOW_SPEED
         self.angular_speed_max = 0.1
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.05
      elseif self.move_type == MOVE_FastWalk then
         self.desired_speed = self.POSITION_LINEAR_NORMAL_SPEED
         self.angular_speed_max = 0.1
         self.angular_acceleration = 0.3
         self.linear_acceleration = 0.02
      elseif self.move_type == MOVE_Run then
         self.desired_speed = self.POSITION_LINEAR_FAST_SPEED
         self.angular_speed_max = 0.2
         self.angular_acceleration = 0.15
         self.linear_acceleration = 0.01
      elseif self.move_type == MOVE_Recal then
         self.desired_speed = self.POSITION_LINEAR_RECAL_SPEED
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
      self.desired_speed = -self.POSITION_LINEAR_VERY_SLOW_SPEED
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
      self.desired_speed = -self.POSITION_LINEAR_SLOW_SPEED
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
         self.desired_speed = self.POSITION_LINEAR_RECAL_SPEED
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
       movement_direction = ( Vector:new( math.cos( self.current_angle ), math.sin( self.current_angle ) ) + self.velocity_delta ):norm()
   end

   self.current_position = self.current_position + movement_direction * self.current_speed * dt

   self.velocity_delta = Vector:new( 0, 0 )

   if math.abs( self.current_speed ) > 30.0 then
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
    table.insert( self.trajectory, { position = point, flag = TRAJECTORY_POINT_Normal } )
    self.trajectory_is_dirty = true
end

function Boid:ResetTrajectory()
    self.trajectory = {}
    self.trajectory_index = 0
    self.trajectory_straight_desired_index = 0
    self.trajectory_last_index_processed = 0
    self.trajectory_last_index = 0
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

function Boid:StartTrajectoryMode( leader )
    self:ChangeLocomotion( LOCOMOTION_Trajectory )
    self.linear_acceleration = 0.4
    self.trajectory_leader = leader
end

function Boid:StartPositionMode()
    self:ChangeLocomotion( LOCOMOTION_Position )
    self.move_type = MOVE_Walk
    self.current_speed = 0.0
end

function Boid:NavigateTrajectory( dt )
    if self.trajectory_index < self.trajectory_last_index then
        self.desired_position = self.trajectory[ self.trajectory_index + 1 ].position
        local current_to_target_vector = self.desired_position - self.current_position
        local linear_speed = self.TRAJECTORY_LINEAR_NORMAL_SPEED
        local angle_speed = self.angle_blend
        local linear_acceleration = self.linear_acceleration
        
        if self.trajectory_index > 0 then
            if self.trajectory[ self.trajectory_index ].flag == TRAJECTORY_POINT_VerySlow then
                linear_speed = self.TRAJECTORY_LINEAR_VERY_SLOW_SPEED
                angle_speed = self.TRAJECTORY_ANGULAR_SLOW_SPEED
            elseif self.trajectory[ self.trajectory_index ].flag == TRAJECTORY_POINT_Slow then
                linear_speed = self.TRAJECTORY_LINEAR_SLOW_SPEED
                angle_speed = self.TRAJECTORY_ANGULAR_SLOW_SPEED
            elseif self.trajectory[ self.trajectory_index ].flag == TRAJECTORY_POINT_Normal then
                linear_speed = self.TRAJECTORY_LINEAR_NORMAL_SPEED
                angle_speed = self.TRAJECTORY_ANGULAR_SLOW_SPEED
            elseif self.trajectory[ self.trajectory_index ].flag == TRAJECTORY_POINT_Stop then
                linear_speed = IsAlmostEqual( WrapAngle( self.current_angle ), WrapAngle( self.sight_angle ), 0.01 ) and self.TRAJECTORY_LINEAR_VERY_SLOW_SPEED or 0
                angle_speed = self.TRAJECTORY_ANGULAR_VERY_SLOW_SPEED
            end
        end
        
        if self.trajectory_follows then
            local leader_position_index = self.trajectory_leader:GetLastTrajectoryIndex()
            leader_position_index = leader_position_index == -1 and #self.trajectory or leader_position_index
            local leader_to_boid_index_difference = leader_position_index - self.trajectory_index
            
            if leader_to_boid_index_difference < self.TRAJECTROY_MINIMUM_SLOT_TO_DETECT_LEADER then
                if self.trajectory_leader.current_speed < linear_speed then
                    linear_speed = self.trajectory_leader.current_speed
                    linear_acceleration = self.TRAJECTROY_JOIN_LEADER_ACCELERATION
                end
            end
        end
        
        self.desired_speed = linear_speed
        self.current_speed = self.current_speed + ( self.desired_speed - self.current_speed ) * linear_acceleration
        self.current_position = self.current_position + current_to_target_vector:norm() * self.current_speed * dt
        
        self.current_angle = current_to_target_vector:ang() - 90 * math.pi / 180
        local angle_sight_speed = WrapAngle( self.current_angle - self.sight_angle ) * angle_speed
        self.sight_angle = WrapAngle( angle_sight_speed + self.sight_angle )
        
        if ( self.current_position - self.desired_position ):r() < Boid.MAX_DISTANCE_TO_TRAJECTORY_SLOT then
            self.trajectory_index = self.trajectory_index + 1
        end
    end
end

function Boid:UpdateTrajectoryProcessing( dt )    
    if self.trajectory_last_index_processed < #self.trajectory and self.trajectory_is_dirty then
        if self.trajectory_last_index_processed == 0 then
            self.trajectory_last_index_processed = self.trajectory_last_index_processed + 1
            self.trajectory[ self.trajectory_last_index_processed ].flag = TRAJECTORY_POINT_Normal
        else
            local last_direction
            
            for index = self.trajectory_last_index_processed + 1, #self.trajectory do
                if self.trajectory_last_index_processed > 1 then
                    last_direction = ( self.trajectory[ self.trajectory_last_index_processed ].position - self.trajectory[ self.trajectory_last_index_processed - 1 ].position ):norm()
                else
                    last_direction = ( self.trajectory[ self.trajectory_last_index_processed + 1 ].position - self.trajectory[ self.trajectory_last_index_processed ].position ):norm()
                end
                local current_direction = ( self.trajectory[ index ].position - self.trajectory[ index - 1 ].position ):norm()
                local current_angle = math.acos( last_direction:dot( current_direction ) / ( last_direction:r() * current_direction:r() ) )
                
                if current_angle >= ( self.MAX_ANGLE_TO_STOP * math.pi / 180 ) then
                    self:ProcessStop( index )
                elseif current_angle >= ( self.MAX_ANGLE_TO_VERY_SLOW * math.pi / 180 ) then
                    self:ProcessVerySlow( index )
                elseif current_angle >= ( self.MAX_ANGLE_TO_SLOW * math.pi / 180 ) then
                    self:ProcessSlow( index )
                else
                    self:ProcessNormal( index )
                end
                
                self.trajectory_last_index_processed = self.trajectory_last_index_processed + 1
            end
        
            self.trajectory_is_dirty = false
        end
    end
end

function Boid:ProcessStop( index )
  local first_index
  local last_index
  local start_index
  
  first_index = index - self.TRAJECTORY_VERY_SLOW_POINT_COUNT
  last_index = index - 1
  first_index = first_index > 0 and first_index or 1
  last_index = last_index > 0 and last_index or 1
  start_index = first_index
  
  for current_index = first_index, last_index do
    self.trajectory[ current_index ].flag = TRAJECTORY_POINT_VerySlow
  end
  
  first_index = start_index - self.TRAJECTORY_SLOW_POINT_COUNT
  last_index = start_index - 1
  first_index = first_index > 0 and first_index or 1
  last_index = last_index > 0 and last_index or 1
  
  for current_index = first_index, last_index do
    self.trajectory[ current_index ].flag = TRAJECTORY_POINT_Slow
  end
  
  self.trajectory[ index ].flag = TRAJECTORY_POINT_Stop
end

function Boid:ProcessVerySlow( index )
  local first_index
  local last_index
  
  first_index = index - self.TRAJECTORY_SLOW_POINT_COUNT
  first_index = first_index > 0 and first_index or 1
  last_index = index - 1
  last_index = last_index > 0 and last_index or 1
  
  for current_index = first_index, last_index do
    self.trajectory[ current_index ].flag = TRAJECTORY_POINT_Slow
  end
  
  self.trajectory[ index ].flag = TRAJECTORY_POINT_VerySlow
end

function Boid:ProcessSlow( index )
  self.trajectory[ index ].flag = TRAJECTORY_POINT_Slow
end

function Boid:ProcessNormal( index )
  local previous_index = index - 1
  if previous_index > 0 then
      if self.trajectory[ previous_index ].flag == TRAJECTORY_POINT_Stop then
          self.trajectory[ index ].flag = TRAJECTORY_POINT_VerySlow
      elseif self.trajectory[ previous_index ].flag == TRAJECTORY_POINT_VerySlow then
          for current_index = index - self.TRAJECTORY_VERY_SLOW_POINT_COUNT, index - 2 do
            if current_index > 0 then
              if self.trajectory[ current_index ].flag ~= TRAJECTORY_POINT_VerySlow then
                self.trajectory[ index ].flag = TRAJECTORY_POINT_VerySlow
                return
              end
            end
          end
          
          self.trajectory[ index ].flag = TRAJECTORY_POINT_Slow
      elseif self.trajectory[ previous_index ].flag == TRAJECTORY_POINT_Slow then
          for current_index = index - self.TRAJECTORY_SLOW_POINT_COUNT, index - 2 do
            if current_index > 0 then
              if self.trajectory[ current_index ].flag ~= TRAJECTORY_POINT_Slow then
                self.trajectory[ index ].flag = TRAJECTORY_POINT_Slow
                return
              end
            end
          end
          
          self.trajectory[ index ].flag = TRAJECTORY_POINT_Normal
      else
          self.trajectory[ index ].flag = TRAJECTORY_POINT_Normal
      end
  else
      self.trajectory[ index ].flag = TRAJECTORY_POINT_Normal
  end
end

function Boid:IsInTrajectoryMode()
  return self.locomotion_state == LOCOMOTION_Trajectory
end

function Boid:GetLastTrajectoryIndex()
    return self.trajectory_index
end
