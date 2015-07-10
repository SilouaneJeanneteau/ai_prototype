require 'vector'

Group =
{
   identity = "Group class"
}

Group.MIN_DISTANCE_TO_LEADER = 5.0
Group.MAX_DISTANCE_TO_LEADER = 25.0
Group.SLOW_WALK_DISTANCE_THRESHOLD = 10.0
Group.WALK_DISTANCE_THRESHOLD = 40.0
Group.FAST_WALK_DISTANCE_THRESHOLD = 50.0
Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER = 30.0
Group.RUN_MAX_DISTANCE_TO_LEADER = 500.0
Group.MIN_DISTANCE_TO_OTHER = 10.0
Group.CHANGE_FORMATION_FROM_GROUPED_MIN_DISTANCE = 40.0
Group.CHANGE_FORMATION_FROM_SINGLE_LINE_MIN_DISTANCE = 20.0
Group.MAX_DISTANCE_TO_RECAL = 1.0
Group.MAX_SLOT_PER_CIRCLE = 8
Group.CIRCLE_RADIUS = 50.0
Group.Circle_MAX_DISTANCE = 1 + Group.CIRCLE_RADIUS * 2
Group.MAX_DISTANCE_TO_GROUPED_MEETING_POINT = 40.0
Group.SINGLE_LINE_SAMPLE_DISTANCE = 10.0
Group.LINE_SLOT_MIN_DISTANCE = 10.0
Group.LINE_FIRST_SLOT_MIN_DISTANCE = 100.0
Group.LINE_SLOT_MIN_INDEX_DISTANCE = 5
Group.RECAL_DISTANCE_THRESHOLD = 50.0

function Group:new( table, new_leader )
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   instance.element_table = table
   instance.element_state_table = {}
   instance.order_table = {}
   instance.leader = new_leader
   instance.leader_averaged_position = new_leader.current_position
   instance.leader_basic_averaged_position = new_leader.current_position
   instance.leader_averaged_direction = new_leader:GetVelocity():norm()
   instance.element_relative_position_table = {}
   instance.last_desired_position_table = {}
   instance.slot_table = {}
   instance.order_inc = 1
   instance.last_search_force = Vector:new( 0, 0 )
   instance.line_following_trail = {}
   instance.line_slot_order_table = {}
   instance.it_waits_to_be_further_away = false
   instance.last_leader_position = Vector:new( 0, 0 )
   instance.leader_away_timer = 0.0
   instance:ResetSearch()

   for index = 1, #instance.element_table do
      instance.last_desired_position_table[ index ] = { it_is_enabled = false, last_leader_position = Vector:new( 0.0, 0.0 ), last_formation_type = FORMATION_Grouped, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = Group.Circle_MAX_DISTANCE }
   end

   instance:ApplyOrder()

   instance:ChangeFormation( FORMATION_Grouped )
   
   instance:ResetSearch()
   instance:UpdateSearch()

   return instance
end

function Group:ApplyOrder()
    for i in ipairs( self.element_table ) do
        self.order_table[ i ] = i
    end
end

function Group:ResetSearch()
    for i, _ in ipairs( self.element_table ) do
        self.element_state_table[ i ] = SEARCH_First
    end
end

function Group:UpdateLeaderAveragedPosition( dt )
    local angle_is_above_threshold = AngleBetweenVectors( self.leader:GetVelocity():norm(), self.leader_averaged_direction ) > 45 * math.pi / 180
    
    self.leader_basic_averaged_position = self.leader_basic_averaged_position + ( self.leader.current_position - self.leader_basic_averaged_position ) * 0.03
    self.leader_averaged_direction = ( self.leader_averaged_direction + ( self.leader:GetVelocity():norm() - self.leader_averaged_direction ) * 0.1 ):norm()
    
    local projected_averaged_onto_direction = ProjectPointOntoLine( self.leader_basic_averaged_position, self.leader_basic_averaged_position + self.leader_averaged_direction * 10.00, self.leader.current_position )
    
    if not angle_is_above_threshold then
        self.leader_away_timer = self.leader_away_timer + dt
        if not self.it_waits_to_be_further_away or ( ( self.leader.current_position - self.last_leader_position ):r() > 200.0 or self.leader_away_timer >= 3.0 ) then
            self.leader_averaged_position = self.leader_averaged_position + ( projected_averaged_onto_direction - self.leader_averaged_position ) * 0.03
            self.it_waits_to_be_further_away = false
        end
    else
        self.it_waits_to_be_further_away = true
        self.last_leader_position = self.leader.current_position
        self.leader_away_timer = 0.0
    end
end

function Group:ResetAveragedPosition()
    self.it_waits_to_be_further_away = false
    self.last_leader_position = self.leader.current_position
    self.leader_averaged_direction = self.leader:GetVelocity():norm()
    self.leader_basic_averaged_position = self.leader.current_position
    self.leader_away_timer = 0.0    
end

function Group:UpdateSearch()
    local it_should_have_force = false
    local force_sum = Vector:new( 0, 0 )
    local element_searching_count = #self.element_state_table
    
    for i, it_is_searching in ipairs( self.element_state_table ) do     
        if it_is_searching == SEARCH_First and not self.last_desired_position_table[ self.order_table[ i ] ].it_is_enabled then
            it_should_have_force = true
            local element_to_group_center_vector = self.leader_averaged_position - self.element_table[ i ].current_position
            if element_to_group_center_vector:r() > Group.CIRCLE_RADIUS then
                force_sum = force_sum + element_to_group_center_vector:norm()
            end
        end
    end
    
    if force_sum:r() == 0.0 and it_should_have_force then
        force_sum = self.last_search_force
    end
    
    if force_sum:r() > 0.0 then
        force_sum = force_sum:norm()
        self.last_search_force = force_sum
    
        if self.formation_type == FORMATION_Grouped then
            local force_position = self.leader_averaged_position + force_sum * Group.CIRCLE_RADIUS
            
            local closest_distance = -1
            local closest_index = -1
            local closest_slot_position = -1
            for i, slot in ipairs( self.slot_table ) do
                local current_slot_position = self.leader_averaged_position + slot.position * Group.CIRCLE_RADIUS
                local current_distance = ( force_position - current_slot_position ):r()
                
                if closest_index == -1 or current_distance < closest_distance then
                    closest_index = i
                    closest_distance = current_distance
                    closest_slot_position = current_slot_position
                end
            end
            
            local sorted_element_table = {}
            ------------------------
            --local first_sorted_table = {}
            --local inc = 1
            
            --for i, _ in ipairs( self.element_table ) do
            --    if self.element_state_table[ i ] ~= SEARCH_First then
            --        first_sorted_table[ inc ] = i
            --        inc = inc + 1
            --    end
            --end
            
            --table.sort( first_sorted_table, function( a, b ) local a_distance = ( self.element_table[ a ].current_position - closest_slot_position ):r() local b_distance = ( self.element_table[ b ].current_position - closest_slot_position ):r() return a_distance > b_distance end )
            
            --local second_sorted_table = {}
            --local inc = 1
            --for i, _ in ipairs( self.element_table ) do
            --    if self.element_state_table[ i ] == SEARCH_First then
            --        second_sorted_table[ inc ] = i
            --        inc = inc + 1
            --    end
            --end
            
            --table.sort( second_sorted_table, function( a, b ) local a_distance = ( self.element_table[ a ].current_position - closest_slot_position ):r() local b_distance = ( self.element_table[ b ].current_position - closest_slot_position ):r() return a_distance > b_distance end )
            
            --local inc = 1
            --for _, index in ipairs( first_sorted_table ) do
            --    sorted_element_table[ inc ] = index
            --    inc = inc + 1
            --end
            --for _, index in ipairs( second_sorted_table ) do
            --    sorted_element_table[ inc ] = index
            --    inc = inc + 1
            --end
            ---------------------------OR
            for i, _ in ipairs( self.element_table ) do
                sorted_element_table[ i ] = i
            end
            
            table.sort( sorted_element_table, function( a, b ) local a_distance = ( self.element_table[ a ].current_position - closest_slot_position ):r() local b_distance = ( self.element_table[ b ].current_position - closest_slot_position ):r() return a_distance > b_distance end )
            
            for index = 1, Group.MAX_SLOT_PER_CIRCLE do
                self.slot_table[ index ].element_index = -1
            end
            
            local ordered_slot_index_table = self:GetOrderedSlotIndexTable( closest_slot_position )
            for i, sorted_index in ipairs( sorted_element_table ) do
                local closest_slot_index = self:FindClosestFreeSlotInTable( self.element_table[ sorted_index ].current_position, ordered_slot_index_table, element_searching_count )--ordered_slot_index_table[ i ]
                self.slot_table[ closest_slot_index ].element_index = sorted_index
                
                if not self.last_desired_position_table[ self.order_table[ sorted_index ] ].it_is_enabled then
                    self.element_relative_position_table[ self.order_table[ sorted_index ] ] = self.slot_table[ closest_slot_index ].position * Group.CIRCLE_RADIUS
                end
            end
        elseif self.formation_type == FORMATION_SingleLine then
            --self.todo.x = 3
        end
    end
end

function Group:FindClosestFreeSlotInTable( position, slot_index_table, last_index )
    local closest_index = -1
    local closest_distance = -1
    for index = 1, last_index do
        local slot_index = slot_index_table[ index ]
        if self.slot_table[ slot_index ].element_index == -1 then
            local current_distance = ( position - ( self.leader_averaged_position + self.slot_table[ slot_index ].position * Group.CIRCLE_RADIUS ) ):r()
            
            if closest_index == -1 or current_distance < closest_distance then
                closest_index = slot_index
                closest_distance = current_distance
            end
        end
    end
    
    return closest_index
end

function Group:GetOrderedSlotIndexTable( position )
    local sorted_slot_table = {}
    for index = 1, Group.MAX_SLOT_PER_CIRCLE do
        sorted_slot_table[ index ] = index
    end
    
    table.sort( sorted_slot_table, function( a, b ) local a_distance = ( ( self.leader_averaged_position + self.slot_table[ a ].position * Group.CIRCLE_RADIUS ) - position ):r() local b_distance = ( ( self.leader_averaged_position + self.slot_table[ b ].position * Group.CIRCLE_RADIUS ) - position ):r() return a_distance < b_distance end )
    
    return sorted_slot_table
end

function Group:FindClosestFreeSlot( position )
    local sorted_slot_table = {}
    local inc = 1
    for index = 1, Group.MAX_SLOT_PER_CIRCLE do
        if self.slot_table[ index ].element_index == -1 then
            sorted_slot_table[ inc ] = index
            inc = inc + 1
        end
    end
    
    table.sort( sorted_slot_table, function( a, b ) local a_distance = ( ( self.leader_averaged_position + self.slot_table[ a ].position * Group.CIRCLE_RADIUS ) - position ):r() local b_distance = ( ( self.leader_averaged_position + self.slot_table[ b ].position * Group.CIRCLE_RADIUS ) - position ):r() return a_distance < b_distance end )
    
    if #sorted_slot_table > 0 then
        return sorted_slot_table[ 1 ]
    end
    
    return -1
end

function Group:OnAddElement()
    local last_index = #self.element_table  
    for index = 1, #self.last_desired_position_table do
        self.last_desired_position_table[ index ].must_recal = true
        self.element_state_table[ index ] = self.element_state_table[ index ] == SEARCH_First and SEARCH_First or SEARCH_New
    end

    self.last_desired_position_table[ last_index ] = { it_is_enabled = false, last_leader_position = Vector:new( 0.0, 0.0 ), last_formation_type = FORMATION_Grouped, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = Group.Circle_MAX_DISTANCE }
    self.order_table[ last_index ] = last_index
    self.element_state_table[ last_index ] = SEARCH_First
    self.element_relative_position_table[ last_index ] = self.element_table[ last_index ].current_position
    self.line_slot_order_table[ last_index ] = { it_follows = true, slot_index = 0 }
    self.element_table[ last_index ].trajectory_follows = true

    self:UpdateSearch()
    
    for _, point in ipairs( self.line_following_trail ) do
        self.element_table[ last_index ]:AddToTrajectory( point )
    end
end

function Group:ChangeFormation( formation_type )
   if formation_type ~= self.formation_type then
      if self.formation_type == FORMATION_Grouped then
         self:ExitGroupedFormation()
      elseif self.formation_type == FORMATION_SingleLine then
         self:ExitSingleLineFormation()
      end

      self.formation_type = formation_type

      if self.formation_type == FORMATION_Grouped then
        self:EnterGroupedFormation()
      elseif self.formation_type == FORMATION_SingleLine then
        self:EnterSingleLineFormation()
      end
   end
end

function Group:Update( dt )
    self:UpdateLeaderAveragedPosition( dt )
    if self.formation_type == FORMATION_Grouped then
    elseif self.formation_type == FORMATION_SingleLine then
        self:TryToInsertTrailPosition( self.leader.current_position )
    end
    
    for i, _ in ipairs( self.element_table ) do
        self:ApplyFormation( i, self.last_desired_position_table[ self.order_table[ i ] ].it_is_enabled and self.last_desired_position_table[ self.order_table[ i ] ].last_formation_type or self.formation_type, dt )
    end
end

function Group:Draw()    
    if self.formation_type == FORMATION_Grouped then
        for i, slot in ipairs( self.slot_table ) do
           local slot_position
           if slot.element_index ~= -1 then
               love.graphics.setColor( 0, 128, 211, 255 )
           else
               love.graphics.setColor( 211, 128, 0, 255 )
           end
           
           slot_position = self.leader_averaged_position + slot.position * Group.CIRCLE_RADIUS
           
           love.graphics.translate( slot_position.x, slot_position.y )
           love.graphics.circle( "fill", 0, 0, 5.0, 100 )

           love.graphics.origin()
   
           if slot.element_index ~= -1 then
               love.graphics.setColor( 0, 0, 0, 255 )
               love.graphics.translate( slot_position.x, slot_position.y )
               love.graphics.print( slot.element_index, 0, 0, 0, 2, 2 )

               love.graphics.origin()
           end
        end
    end
    
    for _, trail in ipairs( self.line_following_trail ) do
       love.graphics.setColor( 128, 11, 211, 255 )
       
       love.graphics.translate( trail.x, trail.y )
       love.graphics.circle( "fill", 0, 0, 5.0, 100 )

       love.graphics.origin()
    end
    
    for i, element in ipairs( self.element_table ) do
       love.graphics.setColor( 0, 128, 211, 255 )
       
       love.graphics.translate( element.desired_position.x, element.desired_position.y )
       love.graphics.circle( "fill", 0, 0, 5.0, 100 )

       love.graphics.origin()
   
       love.graphics.setColor( 0, 0, 0, 255 )
       love.graphics.translate( element.desired_position.x, element.desired_position.y )
       love.graphics.print( i, 0, 0, 0, 2, 2 )

       love.graphics.origin()
    end
end

function Group:ApplyFormation( index, formation_type, dt )
  if formation_type == FORMATION_Grouped then
    self:ApplyGroupedFormation( index, dt )
  elseif formation_type == FORMATION_SingleLine then
    self:ApplySingleLineFormation( index, dt )
  end
end

-- Specific to each formation

function Group:ApplyGroupedFormation( index, dt )
  self:UpdateGroupedFormation( index, dt )
  
  if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
    local distance = ( self.element_table[ index ].current_position - self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position ):r()
    if distance <= Group.MAX_DISTANCE_TO_GROUPED_MEETING_POINT then
      local correct_order_index = -1
      for order_index = 1, #self.order_table do
        if self.order_table[ order_index ] == index then
            correct_order_index = order_index
            break
        end
      end
      
      --if self.order_inc > 3 then
      --  self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
      --  return
      --end
      
      --local temp_index = self.order_table[ self.order_inc ]
      --self.order_table[ self.order_inc ] = self.order_table[ correct_order_index ]
      --self.order_table[ correct_order_index ] = temp_index
      
      --local temp_last_desired_position = self.last_desired_position_table[ self.order_inc ]
      --self.last_desired_position_table[ self.order_inc ] = self.last_desired_position_table[ correct_order_index ]
      --self.last_desired_position_table[ correct_order_index ] = temp_last_desired_position
      
      --local temp_relative_position = self.element_relative_position_table[ self.order_table[ self.order_inc ] ]
      --self.element_relative_position_table[ self.order_table[ self.order_inc ] ] = self.element_relative_position_table[ self.order_table[ correct_order_index ] ]
      --self.element_relative_position_table[ self.order_table[ correct_order_index ] ] = temp_relative_position
      
      self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
      self.line_slot_order_table[ self.order_table[ index ] ].it_follows = self.order_table[ index ] ~= 1
      self.element_table[ index ].trajectory_follows = true
      
      if index > 1 then
        self.element_table[ index ]:Stop()
        self.element_table[ index ].desired_position = self.element_table[ index ].current_position
        self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position = self.element_table[ index ].desired_position
      end
      
      self.order_inc = self.order_inc + 1
      return
    end
  end
  
  if self.last_desired_position_table[ self.order_table[ index ] ].must_recal then
    if ( self.element_table[ index ].current_position - ( self.leader_averaged_position + self.element_relative_position_table[ self.order_table[ index ] ] ) ):r() <= Group.MAX_DISTANCE_TO_RECAL then
      self.last_desired_position_table[ self.order_table[ index ] ].must_recal = false
      self.element_table[ index ]:Stop()
      self.element_state_table[ index ] = SEARCH_None
      return
    end
  end

  local desired_position

  if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
    desired_position = self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position
  else
    desired_position = self.leader_averaged_position + self.element_relative_position_table[ self.order_table[ index ] ]
  end

  local distance = ( self.element_table[ index ].current_position - desired_position ):r()
    
  local it_must_recal = self.last_desired_position_table[ self.order_table[ index ] ].must_recal
  if it_must_recal then
    it_must_recal = it_must_recal and distance <= self.last_desired_position_table[ self.order_table[ index ] ].recal_max_distance
    self.last_desired_position_table[ self.order_table[ index ] ].must_recal = it_must_recal
  end
  
  if it_must_recal then
    local it_is_idling_or_recal = ( self.element_table[ index ].move_type == MOVE_Idle or self.element_table[ index ].move_type == MOVE_Recal )
    self.element_table[ index ]:GoTo( desired_position, it_is_idling_or_recal and MOVE_Recal or self.element_table[ index ].move_type )
     
    self.last_desired_position_table[ self.order_table[ index ] ].must_recal = it_is_idling_or_recal
  elseif distance >= self.last_desired_position_table[ self.order_table[ index ] ].max_distance then
    self.element_table[ index ]:GoTo( desired_position, ( distance >= Group.RUN_MAX_DISTANCE_TO_LEADER and MOVE_Run or ( distance >= Group.WALK_DISTANCE_THRESHOLD and MOVE_Walk or MOVE_SlowWalk ) ) )
  else
    if not self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
      if self.element_table[ index ].move_type ~= MOVE_Idle then
        self.last_desired_position_table[ self.order_table[ index ] ].must_recal = true
        self.last_desired_position_table[ self.order_table[ index ] ].recal_max_distance = Group.Circle_MAX_DISTANCE
        self.element_table[ index ].move_type = MOVE_Recal
      end
    end
  end
end

function Group:ApplySingleLineFormation( index, dt )
  self:UpdateSingleLineFormation( index, dt )
  
  if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
    local distance = ( self.element_table[ index ].current_position - self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position ):r()
    if distance <= Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER then
      self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
      
      local found_slot_index = -1
      for slot_index, slot in ipairs( self.slot_table ) do
        if slot.element_index == index then
            found_slot_index = slot_index
            break
        end
      end
      
      self.element_relative_position_table[ self.order_table[ index ] ] = self.slot_table[ found_slot_index ].position * Group.CIRCLE_RADIUS
      
      local following_index = self.order_table[ index ] + 1
      
      if following_index <= #self.line_slot_order_table then
        self.line_slot_order_table[ following_index ].it_follows = false
        self.element_table[ following_index ].trajectory_follows = false
      end
      
      self:ResetSearch()
      self:UpdateSearch()
      
      self.element_table[index ]:StartPositionMode()
      
      return
    end
  end
  
  if not self.element_table[ index ]:IsInTrajectoryMode() then
    local desired_position = self.element_relative_position_table[ self.order_table[ index ] ]

    local distance = ( self.element_table[ index ].current_position - desired_position ):r()
    if self.last_desired_position_table[ self.order_table[ index ] ].must_recal then
      self.element_table[ index ]:GoTo( desired_position, MOVE_Recal )
      self.last_desired_position_table[ self.order_table[ index ] ].must_recal = false
    elseif distance >= self.last_desired_position_table[ self.order_table[ index ] ].max_distance then
      self.element_table[ index ]:GoTo( desired_position, distance <= Group.RECAL_DISTANCE_THRESHOLD and MOVE_Recal or MOVE_Walk )
    else
      if not self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
        self.element_table[ index ]:StopNow()
        self.element_state_table[ index ] = SEARCH_None
      end
    end
  end
end

function Group:EnterGroupedFormation()
  local angle_inc = 2 * math.pi / Group.MAX_SLOT_PER_CIRCLE
  for index = 1, Group.MAX_SLOT_PER_CIRCLE do
      self.slot_table[ index ] = { element_index = -1, position = Vector:new( math.cos( index * angle_inc ), math.sin( index * angle_inc ) ):norm() }
  end
   
  for index = 1, #self.element_table do
    local slot_index = math.random( 1, #self.slot_table )
      
    while self.slot_table[ slot_index ].element_index ~= -1 do
      slot_index = math.random( 1, #self.slot_table )
    end
    --self.element_relative_position_table[ index ] = self.slot_table[ slot_index ].position * Group.CIRCLE_RADIUS
    self.slot_table[ slot_index ].element_index = index
  end
  
  self:ResetAveragedPosition()
end

function Group:EnterSingleLineFormation()
  local new_last_leader_position = self.leader.current_position - self.leader:GetMovementDirection() * Group.CHANGE_FORMATION_FROM_GROUPED_MIN_DISTANCE
  for index = 1, #self.element_table do
    self.element_relative_position_table[ index ] = self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position
  end
  
  self.line_following_trail = {}
  table.insert( self.line_following_trail, self.leader.current_position )
  
  self.line_slot_order_table = {}
  
  for i = 1, #self.element_table do
    self.element_table[ i ]:ResetTrajectory()
    self.line_slot_order_table[ i ] = { slot_index = 0, it_follows = ( i ~= 1 ) }
    self.element_table[ i ].trajectory_follows = true
  end
end

function Group:ExitGroupedFormation()
  local new_last_leader_position = self.leader.current_position - self.leader:GetMovementDirection() * Group.CHANGE_FORMATION_FROM_GROUPED_MIN_DISTANCE
  
  for index = 1, #self.slot_table do
    local element_index = self.slot_table[ index ].element_index
    if element_index ~= -1 then
        self.last_desired_position_table[ self.order_table[ element_index ] ] = { it_is_enabled = true, last_leader_position = new_last_leader_position + self.slot_table[ index ].position * Group.CIRCLE_RADIUS, last_formation_type = self.formation_type, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = Group.Circle_MAX_DISTANCE }
    end
  end
  
  self.order_inc = 1
end

function Group:ExitSingleLineFormation()
  local new_last_leader_position = self.line_following_trail[ #self.line_following_trail ]
  for index = 1, #self.element_table do
    self.last_desired_position_table[ index ] = { it_is_enabled = true, last_leader_position = new_last_leader_position, last_formation_type = self.formation_type, max_distance = Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER, must_recal = false, recal_max_distance = Group.Circle_MAX_DISTANCE }
  end
  
  self.order_inc = 1
  
  self.element_table[ self.order_table[ 1 ] ].trajectory_follows = false
end

function Group:TryToInsertTrailPosition( new_position )
    local movement_vector = new_position - self.line_following_trail[ #self.line_following_trail ]
    if movement_vector:r() > Group.SINGLE_LINE_SAMPLE_DISTANCE then
        movement_vector = movement_vector:norm()
        local new_point = self.line_following_trail[ #self.line_following_trail ] + movement_vector * Group.SINGLE_LINE_SAMPLE_DISTANCE
        table.insert( self.line_following_trail, new_point )
        
        for _, boid in ipairs( self.element_table ) do
            boid:AddToTrajectory( new_point )
        end
    end
end

function Group:UpdateSingleLineFormation( index, dt )
    local element = self.element_table[ index ]
    local current_distance = ( element.current_position - self.element_relative_position_table[ self.order_table[ index ] ] ):r()
    if current_distance <= Group.LINE_SLOT_MIN_DISTANCE then        
        local new_trail_index = self.line_slot_order_table[ self.order_table[ index ] ].slot_index + 1
        local max_index
        if not self.line_slot_order_table[ self.order_table[ index ] ].it_follows then
            if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
                max_index = #self.line_following_trail
            else
                max_index = #self.line_following_trail - Group.LINE_SLOT_MIN_INDEX_DISTANCE
            end
        else
            max_index = self.line_slot_order_table[ self.order_table[ index ] - 1 ].slot_index - Group.LINE_SLOT_MIN_INDEX_DISTANCE
        end
        
        if new_trail_index > max_index then
            new_trail_index = max_index
        end
           
       if new_trail_index > 0 and self.line_slot_order_table[ self.order_table[ index ] ].slot_index < new_trail_index then
          if self.line_slot_order_table[ self.order_table[ index ] ].slot_index == 1 then
            self.element_table[ index ]:StartTrajectoryMode( self.line_slot_order_table[ self.order_table[ index ] ].it_follows and self.element_table[ self.order_table[ index ] - 1 ] or self.leader )
          end
           self.element_table[ index ].trajectory_last_index = new_trail_index
           self.line_slot_order_table[ self.order_table[ index ] ].slot_index = new_trail_index
           self.element_relative_position_table[ self.order_table[ index ] ] = self.line_following_trail[ new_trail_index ]
       end
    end
end

function Group:UpdateGroupedFormation( index, dt )

end