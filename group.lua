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

function Group:new( table, new_leader )
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   instance.element_table = table
   instance.element_state_table = {}
   instance.order_table = {}
   instance.leader = new_leader
   instance.element_relative_position_table = {}
   instance.last_desired_position_table = {}
   instance.slot_table = {}
   instance:ResetSearch()

   for index = 1, #instance.element_table do
      instance.last_desired_position_table[ index ] = { it_is_enabled = false, last_leader_position = Vector:new( 0.0, 0.0 ), last_formation_type = FORMATION_Grouped, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = Group.Circle_MAX_DISTANCE }
   end

   instance:ApplyOrder()

   instance:ChangeFormation( FORMATION_Grouped )

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

function Group:UpdateSearch()
    local force_sum = Vector:new( 0, 0 )
    local element_searching_count = 0
    
    for i, it_is_searching in ipairs( self.element_state_table ) do
        if it_is_searching ~= SEARCH_None then
            element_searching_count = element_searching_count + 1
            
            if it_is_searching == SEARCH_First then
                force_sum = force_sum + ( self.leader.current_position - self.element_table[ i ].current_position ):norm()
            end
        end
    end
    
    if force_sum:r() > 0.0 then
        force_sum = force_sum:norm()
    
        if self.formation_type == FORMATION_Grouped then
            local force_position = self.leader.current_position + force_sum * Group.CIRCLE_RADIUS
            
            local closest_distance = -1
            local closest_index = -1
            local closest_slot_position = -1
            for i, slot in ipairs( self.slot_table ) do
                local current_slot_position = self.leader.current_position + slot.position * Group.CIRCLE_RADIUS
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
                
                self.element_relative_position_table[ self.order_table[ sorted_index ] ] = self.slot_table[ closest_slot_index ].position * Group.CIRCLE_RADIUS
            end
        elseif self.formation_type == FORMATION_SingleLine then
            self.todo.x = 3
        end
    end
end

function Group:FindClosestFreeSlotInTable( position, slot_index_table, last_index )
    local closest_index = -1
    local closest_distance = -1
    for index = 1, last_index do
        local slot_index = slot_index_table[ index ]
        if self.slot_table[ slot_index ].element_index == -1 then
            local current_distance = ( position - ( self.leader.current_position + self.slot_table[ slot_index ].position * Group.CIRCLE_RADIUS ) ):r()
            
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
    
    table.sort( sorted_slot_table, function( a, b ) local a_distance = ( ( self.leader.current_position + self.slot_table[ a ].position * Group.CIRCLE_RADIUS ) - position ):r() local b_distance = ( ( self.leader.current_position + self.slot_table[ b ].position * Group.CIRCLE_RADIUS ) - position ):r() return a_distance < b_distance end )
    
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
    
    table.sort( sorted_slot_table, function( a, b ) local a_distance = ( ( self.leader.current_position + self.slot_table[ a ].position * Group.CIRCLE_RADIUS ) - position ):r() local b_distance = ( ( self.leader.current_position + self.slot_table[ b ].position * Group.CIRCLE_RADIUS ) - position ):r() return a_distance < b_distance end )
    
    if #sorted_slot_table > 0 then
        return sorted_slot_table[ 1 ]
    end
    
    return -1
end

function Group:OnAddElement()
  local last_index = #self.element_table
    if self.formation_type == FORMATION_Grouped then        
      self:OnAddElementToGroupedFormation()        
    elseif self.formation_type == FORMATION_SingleLine then
      self:OnAddElementToSingleLineFormation()
    end
  
    for index = 1, #self.last_desired_position_table do
        self.last_desired_position_table[ index ].must_recal = true
        self.element_state_table[ index ] = self.element_state_table[ index ] == SEARCH_First and SEARCH_First or SEARCH_New
    end

    self.last_desired_position_table[ last_index ] = { it_is_enabled = false, last_leader_position = Vector:new( 0.0, 0.0 ), last_formation_type = FORMATION_Grouped, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = Group.Circle_MAX_DISTANCE }
    self.order_table[ last_index ] = last_index
    self.element_state_table[ last_index ] = SEARCH_First
    
    self:UpdateSearch()
end

function Group:MoveToSlot( element_index, slot_index, it_is_incrementing )
    if self.slot_table[ slot_index ].element_index == - 1 then
        self.element_relative_position_table[ element_index ] = self.slot_table[ slot_index ].position * Group.CIRCLE_RADIUS
        self.slot_table[ slot_index ].element_index = element_index
        
        return true
    else
        local next_slot_index = ( it_is_incrementing and ( slot_index + 1 ) or ( slot_index - 1 ) )
        
        if next_slot_index > 0 and next_slot_index <= #self.slot_table then
            local next_element_index = self.slot_table[ slot_index ].element_index
            
            if self:MoveToSlot( next_element_index, next_slot_index, it_is_incrementing ) then
                self.element_relative_position_table[ element_index ] = self.slot_table[ slot_index ].position * Group.CIRCLE_RADIUS
                self.slot_table[ slot_index ].element_index = element_index
                
                return true
            end
        else
            return false
        end
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

      self:UpdateSearch()
   end
end

function Group:Update( dt )
    for i, _ in ipairs( self.element_table ) do
        self:ApplyFormation( i, self.last_desired_position_table[ self.order_table[ i ] ].it_is_enabled and self.last_desired_position_table[ self.order_table[ i ] ].last_formation_type or self.formation_type )
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
           
           slot_position = self.leader.current_position + slot.position * Group.CIRCLE_RADIUS
           
           love.graphics.translate( slot_position.x, slot_position.y )
           love.graphics.circle( "fill", 0, 0, 5.0, 100 )

           love.graphics.origin()
   
           if slot.element_index ~= -1 then
               love.graphics.setColor( 0, 0, 0, 255 )
               love.graphics.translate( slot_position.x, slot_position.y )
               love.graphics.print( self.order_table[ slot.element_index ], 0, 0, 0, 2, 2 )

               love.graphics.origin()
           end
        end
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

function Group:UpdateOrder()
   local done_table = {}
   for i, _ in ipairs( self.element_table ) do
      done_table[ i ] = false
   end
   
   for i, element in ipairs( self.element_table ) do
      local closest_index = -1
      local closest_distance = -1
      for j, slot in ipairs( self.element_relative_position_table ) do
         if not done_table[ j ] then
            local current_distance = ( element.current_position - ( self.leader.current_position + slot ) ):r()
            
            if closest_index == -1 or current_distance < closest_distance then
               closest_distance = current_distance
               closest_index = j
            end
         end
      end
      
      done_table[ closest_index ] = true
      
      self.order_table[ i ] = closest_index
   end
end

function Group:ApplyFormation( index, formation_type )
  if formation_type == FORMATION_Grouped then
    self:ApplyGroupedFormation( index )
  elseif formation_type == FORMATION_SingleLine then
    self:ApplySingleLineFormation( index )
  end
end

-- Specific to each formation

function Group:ApplyGroupedFormation( index )
  if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
    local distance = ( self.element_table[ index ].current_position - self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position ):r()
    if distance <= Group.MAX_DISTANCE_TO_LEADER then
      self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
    end
  end
  
  if self.last_desired_position_table[ self.order_table[ index ] ].must_recal then
    if ( self.element_table[ index ].current_position - ( self.leader.current_position + self.element_relative_position_table[ self.order_table[ index ] ] ) ):r() <= Group.MAX_DISTANCE_TO_RECAL then
      self.last_desired_position_table[ self.order_table[ index ] ].must_recal = false
      --self.element_table[ index ].current_position = self.leader.current_position + self.element_relative_position_table[ self.order_table[ index ] ]
      self.element_table[ index ]:Stop()
      self.element_state_table[ index ] = SEARCH_None
      return
    end
  end

  local desired_position

  if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
    desired_position = self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position
  else
    desired_position = self.leader.current_position + self.element_relative_position_table[ self.order_table[ index ] ]
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
    if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
      self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
    else
      if self.element_table[ index ].move_type ~= MOVE_Idle then
        self.last_desired_position_table[ self.order_table[ index ] ].must_recal = true
        self.last_desired_position_table[ self.order_table[ index ] ].recal_max_distance = Group.Circle_MAX_DISTANCE
        self.element_table[ index ].move_type = MOVE_Recal
      end
    end
  end
end

function Group:ApplySingleLineFormation( index )
  if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
    local distance = ( self.element_table[ index ].current_position - self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position ):r()
    if distance <= Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER then
      self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
    end
  end

  local current_leader = index == 1 and self.leader or self.element_table[ index - 1 ]
  local desired_position = current_leader.current_position - current_leader:GetMovementDirection() * Group.MIN_DISTANCE_TO_OTHER

  local distance = ( self.element_table[ index ].current_position - desired_position ):r()
  if self.last_desired_position_table[ index ].must_recal then
    self.element_table[ index ]:GoTo( desired_position, MOVE_Recal )
    self.last_desired_position_table[ index ].must_recal = false
  elseif distance >= self.last_desired_position_table[ index ].max_distance then
    self.element_table[ index ]:GoTo( desired_position, distance >= Group.FAST_WALK_DISTANCE_THRESHOLD and MOVE_Walk or MOVE_SlowWalk )
  else
    if not self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
      self.element_table[ index ]:StopNow()
      self.element_state_table[ index ] = SEARCH_None
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
    self.element_relative_position_table[ index ] = self.slot_table[ slot_index ].position * Group.CIRCLE_RADIUS
    self.slot_table[ slot_index ].element_index = index
  end
end

function Group:EnterSingleLineFormation()
  local angle_inc = Group.MIN_DISTANCE_TO_OTHER
  for index = 1, #self.element_table do
    self.element_relative_position_table[ index ] = Vector:new( index * angle_inc, 0.0 )
  end
end

function Group:ExitGroupedFormation()
  local new_last_leader_position = self.leader.current_position - self.leader:GetMovementDirection() * Group.CHANGE_FORMATION_FROM_GROUPED_MIN_DISTANCE
  for index = 1, #self.element_table do
    self.last_desired_position_table[ index ] = { it_is_enabled = true, last_leader_position = new_last_leader_position, last_formation_type = self.formation_type, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = Group.Circle_MAX_DISTANCE }
  end
end

function Group:ExitSingleLineFormation()
  local new_last_leader_position = self.leader.current_position - self.leader:GetMovementDirection() * Group.CHANGE_FORMATION_FROM_SINGLE_LINE_MIN_DISTANCE
  for index = 1, #self.element_table do
    self.last_desired_position_table[ index ] = { it_is_enabled = true, last_leader_position = new_last_leader_position, last_formation_type = self.formation_type, max_distance = Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER, must_recal = false, recal_max_distance = Group.Circle_MAX_DISTANCE }
  end
end

function Group:OnAddElementToGroupedFormation()
  local last_index = #self.element_table
  local closest_distance = -1
  local closest_index = -1
  for slot_index, slot in ipairs( self.slot_table ) do
      local slot_position = self.leader.current_position + slot.position * Group.CIRCLE_RADIUS
      local current_distance = ( self.element_table[ last_index ].current_position - slot_position ):r()
      
      if closest_index == -1 or current_distance < closest_distance then
          closest_distance = current_distance
          closest_index = slot_index
      end
  end
  
  --if not self:MoveToSlot( last_index, closest_index, true ) then
  --    self:MoveToSlot( last_index, closest_index, false )
  --else
  --    local current_slot_index = closest_index - 1
  --    current_slot_index = current_slot_index < 1 and #self.slot_table or current_slot_index
  --    local slot_to_go = current_slot_index - 1
  --    slot_to_go = slot_to_go < 1 and #self.slot_table or slot_to_go
  --    local current_element_index = self.slot_table[ current_slot_index ].element_index
  --    self.slot_table[ current_slot_index ].element_index = - 1
  --    self:MoveToSlot( current_element_index, slot_to_go, false )
  --end
end

function Group:OnAddElementToSingleLineFormation()
  local last_index = #self.element_table
  local angle_inc = Group.MIN_DISTANCE_TO_OTHER
  for index = 1, #self.element_table do
    self.element_relative_position_table[ index ] = Vector:new( index * angle_inc, 0.0 )
  end
end