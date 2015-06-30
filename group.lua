require 'vector'

Group =
{
   identity = "Group class"
}

Group.MIN_DISTANCE_TO_LEADER = 50.0
Group.MAX_DISTANCE_TO_LEADER = 80.0
Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER = 30.0
Group.RUN_MAX_DISTANCE_TO_LEADER = 400.0
Group.MIN_DISTANCE_TO_OTHER = 10.0
Group.CHANGE_FORMATION_MIN_DISTANCE = 20.0
Group.MAX_DISTANCE_TO_RECAL = 1.0
Group.MAX_SLOT_PER_CIRCLE = 8

function Group:new( table, new_leader )
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   instance.element_table = table
   instance.order_table = {}
   instance.leader = new_leader
   instance.element_relative_position_table = {}
   instance.last_desired_position_table = {}
   instance.slot_table = {}
   instance:ChangeFormation( FORMATION_Grouped )
   instance:ApplyOrder()

   return instance
end

function Group:ApplyOrder()
    for i in ipairs( self.element_table ) do
        self.order_table[ i ] = i
    end
end

function Group:OnAddElement()
    local last_index = #self.element_table
   
    if self.formation_type == FORMATION_Grouped then        
        local closest_distance = -1
        local closest_index = -1
        for slot_index, slot in ipairs( self.slot_table ) do
            local slot_position = self.leader.current_position + slot.position * Group.MIN_DISTANCE_TO_LEADER
            local current_distance = ( self.element_table[ last_index ].current_position - slot_position ):r()
            
            if closest_index == -1 or current_distance < closest_distance then
                closest_distance = current_distance
                closest_index = slot_index
            end
        end
        
        if not self:MoveToSlot( last_index, closest_index, true ) then
            self:MoveToSlot( last_index, closest_index, false )
        --else
        --    local current_slot_index = closest_index - 1
        --    current_slot_index = current_slot_index < 1 and #self.slot_table or current_slot_index
        --    local slot_to_go = current_slot_index - 1
        --    slot_to_go = slot_to_go < 1 and #self.slot_table or slot_to_go
        --    local current_element_index = self.slot_table[ current_slot_index ].element_index
        --    self.slot_table[ current_slot_index ].element_index = - 1
        --    self:MoveToSlot( current_element_index, slot_to_go, false )
        end
        
    elseif self.formation_type == FORMATION_SingleLine then
        local angle_inc = Group.MIN_DISTANCE_TO_OTHER
        for index = 1, #self.element_table do
            self.element_relative_position_table[ index ] = Vector:new( index * angle_inc, 0.0 )
        end
    end
  
    for index = 1, #self.last_desired_position_table do
        self.last_desired_position_table[ index ].must_recal = true
    end

    self.last_desired_position_table[ last_index ] = { it_is_enabled = false, last_leader_position = Vector:new( 0.0, 0.0 ), last_formation_type = FORMATION_Grouped, max_distance = Group.MAX_DISTANCE_TO_LEADER, must_recal = false }
    self.order_table[ last_index ] = last_index
end

function Group:MoveToSlot( element_index, slot_index, it_is_incrementing )
    if self.slot_table[ slot_index ].element_index == - 1 then
        self.element_relative_position_table[ element_index ] = self.slot_table[ slot_index ].position * Group.MIN_DISTANCE_TO_LEADER
        self.slot_table[ slot_index ].element_index = element_index
        
        return true
    else
        local next_slot_index = ( it_is_incrementing and ( slot_index + 1 ) or ( slot_index - 1 ) )
        
        if next_slot_index > 0 and next_slot_index <= #self.slot_table then
            local next_element_index = self.slot_table[ slot_index ].element_index
            
            if self:MoveToSlot( next_element_index, next_slot_index, it_is_incrementing ) then
                self.element_relative_position_table[ element_index ] = self.slot_table[ slot_index ].position * Group.MIN_DISTANCE_TO_LEADER
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
      local new_last_leader_position = self.leader.current_position - self.leader:GetMovementDirection() * Group.CHANGE_FORMATION_MIN_DISTANCE
      local current_max_distance = ( formation_type == FORMATION_Grouped and Group.MAX_DISTANCE_TO_LEADER or Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER )
      if self.formation_type == FORMATION_Grouped then
         for index = 1, #self.element_table do
            self.last_desired_position_table[ index ] = { it_is_enabled = true, last_leader_position = new_last_leader_position, last_formation_type = self.formation_type, max_distance = current_max_distance, must_recal = false }
         end
      elseif self.formation_type == FORMATION_SingleLine then
         for index = 1, #self.element_table do
            self.last_desired_position_table[ index ] = { it_is_enabled = true, last_leader_position = new_last_leader_position, last_formation_type = self.formation_type, max_distance = current_max_distance, must_recal = false }
         end
      else
         for index = 1, #self.element_table do
            self.last_desired_position_table[ index ] = { it_is_enabled = false, last_leader_position = Vector:new( 0.0, 0.0 ), last_formation_type = FORMATION_Grouped, max_distance = current_max_distance, must_recal = false }
         end
      end

      self.formation_type = formation_type

      if self.formation_type == FORMATION_Grouped then
         local angle_inc = 2 * math.pi / Group.MAX_SLOT_PER_CIRCLE
         for index = 1, Group.MAX_SLOT_PER_CIRCLE do
             self.slot_table[ index ] = { element_index = -1, position = Vector:new( math.cos( index * angle_inc ), math.sin( index * angle_inc ) ):norm() }
         end
         
         for index = 1, #self.element_table do
            local slot_index = math.random( 1, #self.slot_table )
            
            while self.slot_table[ slot_index ].element_index ~= -1 do
                slot_index = math.random( 1, #self.slot_table )
            end
            self.element_relative_position_table[ index ] = self.slot_table[ slot_index ].position * Group.MIN_DISTANCE_TO_LEADER
            self.slot_table[ slot_index ].element_index = index
         end
      elseif self.formation_type == FORMATION_SingleLine then
         local angle_inc = Group.MIN_DISTANCE_TO_OTHER
         for index = 1, #self.element_table do
            self.element_relative_position_table[ index ] = Vector:new( index * angle_inc, 0.0 )
         end
      end

      self:UpdateOrder()
   end
end

function Group:Update( dt )
   for i, _ in ipairs( self.element_table ) do
      self:ApplyFormation( i, self.last_desired_position_table[ self.order_table[ i ] ].it_is_enabled and self.last_desired_position_table[ self.order_table[ i ] ].last_formation_type or self.formation_type )
   end
end

function Group:Draw()
    if self.formation_type == FORMATION_Grouped then
        for _, slot in ipairs( self.slot_table ) do
           local slot_position
           if slot.element_index ~= -1 then
               love.graphics.setColor( 0, 128, 211, 255 )
           else
               love.graphics.setColor( 211, 128, 0, 255 )
           end
           
           slot_position = self.leader.current_position + slot.position * Group.MIN_DISTANCE_TO_LEADER
           
           love.graphics.translate( slot_position.x, slot_position.y )
           love.graphics.circle( "fill", 0, 0, 5.0, 100 )

           love.graphics.origin()
        end
    end
    
    for _, element in ipairs( self.element_table ) do
       love.graphics.setColor( 0, 128, 211, 255 )
       
       love.graphics.translate( element.desired_position.x, element.desired_position.y )
       love.graphics.circle( "fill", 0, 0, 5.0, 100 )

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
      if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
         local distance = ( self.element_table[ index ].current_position - self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position ):r()
         if distance <= Group.MAX_DISTANCE_TO_LEADER then
            self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
         end
      end
      
      if self.last_desired_position_table[ self.order_table[ index ] ].must_recal then
         if ( self.element_table[ index ].current_position - ( self.leader.current_position + self.element_relative_position_table[ self.order_table[ index ] ] ) ):r() <= Group.MAX_DISTANCE_TO_RECAL then
            self.last_desired_position_table[ self.order_table[ index ] ].must_recal = false
            self.element_table[ index ].current_position = self.element_table[ index ].desired_position
            self.element_table[ index ]:StopNow()
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
      if self.last_desired_position_table[ self.order_table[ index ] ].must_recal then
         self.element_table[ index ]:GoTo( desired_position, self.element_table[ index ].move_type == MOVE_Idle and MOVE_Recal or self.element_table[ index ].move_type )
      elseif distance >= self.last_desired_position_table[ self.order_table[ index ] ].max_distance then
         self.element_table[ index ]:GoTo( desired_position, ( distance >= Group.RUN_MAX_DISTANCE_TO_LEADER and MOVE_Run or MOVE_Walk ) )
      else
         if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
            self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
         else
            self.element_table[ index ]:Stop()
         end
      end
   elseif formation_type == FORMATION_SingleLine then
      if self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
         local distance = ( self.element_table[ index ].current_position - self.last_desired_position_table[ self.order_table[ index ] ].last_leader_position ):r()
         if distance <= Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER then
            self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled = false
         end
      end

      local current_leader = index == 1 and self.leader or self.element_table[ index - 1 ]
      local desired_position

      desired_position = current_leader.current_position - current_leader:GetMovementDirection() * Group.MIN_DISTANCE_TO_OTHER

      local distance = ( self.element_table[ index ].current_position - desired_position ):r()
      if self.last_desired_position_table[ index ].must_recal then
         self.element_table[ index ]:GoTo( desired_position, MOVE_Recal )
         self.last_desired_position_table[ index ].must_recal = false
      elseif distance >= self.last_desired_position_table[ index ].max_distance then
         self.element_table[ index ]:GoTo( desired_position, MOVE_Walk )
      else
         if not self.last_desired_position_table[ self.order_table[ index ] ].it_is_enabled then
            self.element_table[ index ]:Stop()
         end
      end
   end
end