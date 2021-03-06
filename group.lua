require 'vector'
require 'Boid'

Group =
{
   identity = "Group class"
}

Group.ItRendersNumbers = false
Group.ItRendersFormationInfos = false

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

-- Attack mode
Group.ATTACK_MODE_MIN_TIME_TO_COMPUTE_CLOSEST_POSITION_TO_MOVING_ENEMY_GROUP = 0.5
Group.ATTACK_MODE_MIN_DISTANCE_TO_SLOT_AROUND_MOVING_ENEMY_GROUP = 30.0
Group.ATTACK_MODE_MIN_DISTANCE_TO_SLOT_AROUND_MOVING_ENEMY_GROUP_TO_RECAL = 15.0
Group.ATTACK_MODE_NAVIGATION_CIRCLE_SLOT_COUNT = 32
Group.ATTACK_MODE_WAITING_ENEMY_SLOT_COUNT = 32
Group.ATTACK_MODE_ARENA_SIZE = 250.0
Group.ATTACK_MODE_MIN_PERCENTAGE_ENEMY_INSIDE_ARENA = 0.5
Group.ATTACK_MODE_MAX_ENEMY_DISTANCE = 200.0
Group.ATTACK_MODE_MAX_ATTACKED_ENEMY_DISTANCE = 100.0
Group.ATTACK_MODE_HIT_RENDER_MAX_TIME = 1.2
Group.ATTACK_MODE_HIT_RENDER_MAX_SIZE = 10.0
Group.ATTACK_MODE_MIN_ATTACK_TIMER = 2.0
Group.ATTACK_MODE_COOL_DOWN_ATTACK_TIMER = 5.0
Group.ATTACK_MODE_SEARCH_NEW_OPPONENT_MAX_TIME = 4.0

-- Defense mode
Group.DEFENSE_MODE_MIN_LEADER_MOVE_DIST = 150.0
Group.DEFENSE_MODE_HALF_SIGHT_ANGLE = 40.0

function Group:new( table, new_leader, new_coordinator, new_id )
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   instance.element_table = table
   instance.coordinator = new_coordinator
   instance.group_id = new_id
   instance.slot_table = {}
   instance.element_relative_position_table = {}
   
   -- Follow mode
   instance.element_state_table = {}
   instance.order_table = {}
   instance.leader = new_leader
   instance.leader_averaged_position = new_leader.current_position
   instance.leader_basic_averaged_position = new_leader.current_position
   instance.leader_averaged_direction = new_leader:GetVelocity():norm()
   instance.last_desired_position_table = {}
   instance.order_inc = 1
   instance.last_search_force = Vector:new( 0, 0 )
   instance.line_following_trail = {}
   instance.line_slot_order_table = {}
   instance.it_waits_to_be_further_away = false
   instance.last_leader_position = Vector:new( 0, 0 )
   instance.leader_away_timer = 0.0
   instance.formation_radius = Group.CIRCLE_RADIUS
   
   --Fight
   instance.enemy_group_id = -1
   instance.enemy_table = {}
   instance.opponent_match_table = {}
   
   -- Attack mode
   instance.enemy_formation_circle = { radius = 0.0, center = Vector:new( 0.0, 0.0 ) }
   instance.attack_strategy = ATTACK_STRATEGY_WaitToSurround
   instance.attack_arena = { radius = 0.0, center = Vector:new( 0.0, 0.0 ) }
   instance.attack_arena_last_position = Vector:new( 0.0, 0.0 )
   instance.attack_surround_state = SURROUND_FindArena
   instance.attack_last_further_away_slot_index = -1
   instance.attack_arena_can_move = false
   instance.attack_arena_is_moving = false
   instance.attack_arena_speed = 0.0
   instance.navigation_path_point_table = instance:ArrangeSlotsInCircle( Group.ATTACK_MODE_NAVIGATION_CIRCLE_SLOT_COUNT, 4 )
   instance.attack_hit_table = {}
   instance:ResetAttackStrategyPhase()
   instance:ResetEnemyHandlingTable()
   instance:ResetAttackState()
   
   -- Defense mode
   instance.defense_from_attacking_group = {}
   instance.defense_info_table = {}
   instance.defense_last_group_position = Vector:new( 0.0, 0.0 )
   instance:ResetDefenseState()
   
   instance.navigation_plan_table = {}
   
   instance.group_mode = GROUP_Follow
   instance:ResetSearch()

   for index = 1, #instance.element_table do
      instance.last_desired_position_table[ index ] = { it_is_enabled = false, last_leader_position = Vector:new( 0.0, 0.0 ), last_formation_type = FORMATION_Grouped, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = ( instance.formation_radius * 2 + 1 ) }
   end

   instance:ApplyOrder()

   instance:ChangeFormation( FORMATION_Grouped )
   
   instance:ResetSearch()
   instance:UpdateSearch()

   return instance
end

function Group:ChangeGroupMode( mode )
    self.group_mode = mode
end

function Group:ChangeFormationRadius( radius )
    self.formation_radius = radius

    self:ApplyOrder()
   
    self:ResetSearch()
    self:UpdateSearch()
end

function Group:ApplyOrder()
    for i in ipairs( self.element_table ) do
        self.order_table[ i ] = i
    end
end

function Group:ResetSearch()
    self.element_state_table = {}
    for i, _ in ipairs( self.element_table ) do
        self.element_state_table[ i ] = SEARCH_First
    end
end

function Group:ResetSearchForEnemy()
    self.element_state_table = {}
    for i, _ in ipairs( self.enemy_table ) do
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
            if element_to_group_center_vector:r() > self.formation_radius then
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
            local force_position = self.leader_averaged_position + force_sum * self.formation_radius
            
            local closest_distance = -1
            local closest_index = -1
            local closest_slot_position = -1
            for i, slot in ipairs( self.slot_table ) do
                local current_slot_position = self.leader_averaged_position + slot.position * self.formation_radius
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
            
            local ordered_slot_index_table = self:GetOrderedSlotIndexTable( closest_slot_position, self.leader_averaged_position, self.formation_radius, Group.MAX_SLOT_PER_CIRCLE )
            for i, sorted_index in ipairs( sorted_element_table ) do
                local closest_slot_index = self:FindClosestFreeSlotInTable( self.element_table[ sorted_index ].current_position, ordered_slot_index_table, element_searching_count, self.leader_averaged_position, self.formation_radius )--ordered_slot_index_table[ i ]
                self.slot_table[ closest_slot_index ].element_index = sorted_index
                
                if not self.last_desired_position_table[ self.order_table[ sorted_index ] ].it_is_enabled then
                    self.element_relative_position_table[ self.order_table[ sorted_index ] ] = self.slot_table[ closest_slot_index ].position * self.formation_radius
                end
            end
        elseif self.formation_type == FORMATION_SingleLine then
            --self.todo.x = 3
        end
    end
end

function Group:FindClosestFreeSlotInTable( position, slot_index_table, last_index, center_position, radius )
    local closest_index = -1
    local closest_distance = -1
    for index = 1, last_index do
        local slot_index = slot_index_table[ index ]
        if self.slot_table[ slot_index ].element_index == -1 then
            local current_distance = ( position - ( center_position + self.slot_table[ slot_index ].position * radius ) ):r()
            
            if closest_index == -1 or current_distance < closest_distance then
                closest_index = slot_index
                closest_distance = current_distance
            end
        end
    end
    
    return closest_index
end

function Group:GetOrderedSlotIndexTable( position, center_position, radius, slot_count )
    local sorted_slot_table = {}
    for index = 1, slot_count do
        sorted_slot_table[ index ] = index
    end
    
    table.sort( sorted_slot_table, function( a, b ) local a_distance = ( ( center_position + self.slot_table[ a ].position * radius ) - position ):r() local b_distance = ( ( center_position + self.slot_table[ b ].position * radius ) - position ):r() return a_distance < b_distance end )
    
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
    
    table.sort( sorted_slot_table, function( a, b ) local a_distance = ( ( self.leader_averaged_position + self.slot_table[ a ].position * self.formation_radius ) - position ):r() local b_distance = ( ( self.leader_averaged_position + self.slot_table[ b ].position * self.formation_radius ) - position ):r() return a_distance < b_distance end )
    
    if #sorted_slot_table > 0 then
        return sorted_slot_table[ 1 ]
    end
    
    return -1
end

function Group:OnAddElement( element_index )
    self.order_table[ element_index ] = element_index
    if self.group_mode == GROUP_Follow then
        for index = 1, #self.last_desired_position_table do
            self.last_desired_position_table[ index ].must_recal = true
            self.element_state_table[ index ] = self.element_state_table[ index ] == SEARCH_First and SEARCH_First or SEARCH_New
        end

        self.last_desired_position_table[ element_index ] = { it_is_enabled = false, last_leader_position = Vector:new( 0.0, 0.0 ), last_formation_type = FORMATION_Grouped, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = ( self.formation_radius * 2 + 1 ) }
        self.element_state_table[ element_index ] = SEARCH_First
        self.element_relative_position_table[ element_index ] = self.element_table[ element_index ].current_position
        self.line_slot_order_table[ element_index ] = { it_follows = true, slot_index = 0 }
        self.element_table[ element_index ].trajectory_follows = true
        self.attack_strategy_phase_table[ element_index ] = { state = WAIT_TO_SURROUND_GoToSlots, timer = -1.0 }

        self:UpdateSearch()
        
        for _, point in ipairs( self.line_following_trail ) do
            self.element_table[ element_index ]:AddToTrajectory( point )
        end
    elseif self.group_mode == GROUP_Defense then
        self:SpreadElementsOntoCircle()
        self.defense_info_table[ element_index ] = { closest_enemy_index = -1 }
    end
end

function Group:OnRemoveElement( element_index )
    if self.group_mode == GROUP_Follow then
        table.remove( self.last_desired_position_table, self.order_table[ element_index ] )
        table.remove( self.element_state_table, self.order_table[ element_index ] )
        table.remove( self.element_relative_position_table, self.order_table[ element_index ] )
        table.remove( self.line_slot_order_table, self.order_table[ element_index ] )
        table.remove( self.attack_strategy_phase_table, self.order_table[ element_index ] )
        
        for _, slot in ipairs( self.slot_table ) do
            if slot.element_index == element_index then
                slot.element_index = -1
                break
            end
        end

        self:UpdateSearch()
    elseif self.group_mode == GROUP_Defense then
        table.remove( self.defense_info_table, self.order_table[ element_index ] )
        self:SpreadElementsOntoCircle()
    end
    
    table.remove( self.order_table, #self.order_table )
end

function Group:OnAddEnemy( enemy_index )
    if self.group_mode == GROUP_Attack or self.group_mode == GROUP_Defense then
        table.insert( self.enemy_table, enemy )
    end
end

function Group:OnRemoveEnemy( enemy_index )
    if self.group_mode == GROUP_Attack or self.group_mode == GROUP_Defense then
        table.remove( self.enemy_table, enemy_index )
        
        for _, opponent in ipairs( self.opponent_match_table ) do
            if opponent == enemy_index then
                opponent = -1
            end
        end
        
        for _, defense_info in ipairs( self.defense_info_table ) do
            if defense.closest_enemy_index == enemy_index then
                defense.closest_enemy_index = -1
            end
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
   end
end

function Group:Update( dt )
    if self.group_mode == GROUP_Follow then
        self:UpdateLeaderAveragedPosition( dt )
        if self.formation_type == FORMATION_Grouped then
        elseif self.formation_type == FORMATION_SingleLine then
            self:TryToInsertTrailPosition( self.leader.current_position )
        end
        
        self:ApplyFollowFormation( dt )
    elseif self.group_mode == GROUP_Attack then
        self:ApplyAttackFormation( dt )
    elseif self.group_mode == GROUP_Defense then
        self:ApplyDefenseFormation( dt )
    end
end

function Group:ApplyFollowFormation( dt )
    for i, _ in ipairs( self.element_table ) do
        self:ApplyFormation( i, self.last_desired_position_table[ self.order_table[ i ] ].it_is_enabled and self.last_desired_position_table[ self.order_table[ i ] ].last_formation_type or self.formation_type, dt )
    end
end

function Group:Draw()
    if self.group_mode == GROUP_Follow then
        if self.formation_type == FORMATION_Grouped then
            for i, slot in ipairs( self.slot_table ) do
               local slot_position
               if slot.element_index ~= -1 then
                   love.graphics.setColor( 0, 128, 211, 255 )
               else
                   love.graphics.setColor( 211, 128, 0, 255 )
               end
               
               slot_position = self.leader_averaged_position + slot.position * self.formation_radius
               
               love.graphics.translate( slot_position.x, slot_position.y )
               love.graphics.circle( "fill", 0, 0, 5.0, 100 )

               love.graphics.origin()
       
               if Group.ItRendersNumbers and slot.element_index ~= -1 then
                   love.graphics.setColor( 0, 0, 0, 255 )
                   love.graphics.translate( slot_position.x, slot_position.y )
                   love.graphics.print( slot.element_index, 0, 0, 0, 2, 2 )

                   love.graphics.origin()
               end
            end
        end
    elseif self.group_mode == GROUP_Attack then
        love.graphics.setColor( 128, 128, 154, 255 )
        love.graphics.circle( "fill", self.attack_arena.center.x, self.attack_arena.center.y, self.attack_arena.radius, 100 )
        
        for i, slot in ipairs( self.slot_table ) do
           local slot_position
           if slot.element_index ~= -1 then
               love.graphics.setColor( 0, 128, 211, 255 )
           else
               love.graphics.setColor( 211, 128, 0, 255 )
           end
           
           slot_position = self.attack_arena.center + slot.position * self.attack_arena.radius
           
           love.graphics.translate( slot_position.x, slot_position.y )
           love.graphics.circle( "fill", 0, 0, 5.0, 100 )

           love.graphics.origin()
   
           if Group.ItRendersNumbers and slot.element_index ~= -1 then
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
   
       if Group.ItRendersNumbers then
           love.graphics.setColor( 0, 0, 0, 255 )
           love.graphics.translate( element.desired_position.x, element.desired_position.y )
           love.graphics.print( i, 0, 0, 0, 2, 2 )

           love.graphics.origin()
       end
    end
    
    if Group.ItRendersFormationInfos then
        love.graphics.setColor( 255, 255, 128 )
        love.graphics.circle( "line", self.enemy_formation_circle.center.x, self.enemy_formation_circle.center.y, self.enemy_formation_circle.radius, 100 )
    end
end

function Group:DrawEffects()
    love.graphics.setColor( 255, 0, 0 )
    for _, hit in ipairs( self.attack_hit_table ) do
        love.graphics.circle( "fill", hit.position.x, hit.position.y, hit.scale, 100 )
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
        self.last_desired_position_table[ self.order_table[ index ] ].recal_max_distance = ( self.formation_radius * 2 + 1 )
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
      
      self.element_relative_position_table[ self.order_table[ index ] ] = self.slot_table[ found_slot_index ].position * self.formation_radius
      
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
  self.slot_table = self:ArrangeSlotsInCircle( Group.MAX_SLOT_PER_CIRCLE, 0 )
   
  for index = 1, #self.element_table do
    local slot_index = math.random( 1, #self.slot_table )
      
    while self.slot_table[ slot_index ].element_index ~= -1 do
      slot_index = math.random( 1, #self.slot_table )
    end
    --self.element_relative_position_table[ index ] = self.slot_table[ slot_index ].position * self.formation_radius
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
        self.last_desired_position_table[ self.order_table[ element_index ] ] = { it_is_enabled = true, last_leader_position = new_last_leader_position + self.slot_table[ index ].position * self.formation_radius, last_formation_type = self.formation_type, max_distance = Group.SLOW_WALK_DISTANCE_THRESHOLD, must_recal = false, recal_max_distance = ( self.formation_radius * 2 + 1 ) }
    end
  end
  
  self.order_inc = 1
end

function Group:ExitSingleLineFormation()
  local new_last_leader_position = self.line_following_trail[ #self.line_following_trail ]
  for index = 1, #self.element_table do
    self.last_desired_position_table[ index ] = { it_is_enabled = true, last_leader_position = new_last_leader_position, last_formation_type = self.formation_type, max_distance = Group.SINGLE_LINE_MAX_DISTANCE_TO_LEADER, must_recal = false, recal_max_distance = ( self.formation_radius * 2 + 1 ) }
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

-- Attack mode

function Group:StartAttackMode( group_id, group_to_attack, group_leader )
    self:ChangeGroupMode( GROUP_Attack )

    self.enemy_group_id = group_id
    self.enemy_formation_circle = { radius = 0.0, center = Vector:new( 0.0, 0.0 ) }
    self:ResetEnemyHandlingTable()
    
    for _, enemy in ipairs( group_to_attack ) do
        table.insert( self.enemy_table, enemy )
    end
    
    if group_leader ~= nil and not group_leader:IsDummy() then
        table.insert( self.enemy_table, group_leader )
    end
end

function Group:ResetEnemyHandlingTable()
    self.enemy_handling_element_table = {}
    for index = 1, #self.element_table do
        self.enemy_handling_element_table[ index ] = { closest_position_from_moving_enemy_group = Vector:new( 0.0, 0.0 ), time_since_last_position_computed = -1.0, slot_index = -1 }
    end
end

function Group:ResetAttackStrategyPhase()
    self.attack_strategy_phase_table = {}
    
    for i = 1, #self.element_table do
        self.attack_strategy_phase_table[ i ] = { state = WAIT_TO_SURROUND_GoToSlots, timer = -1.0 }
    end
end

function Group:ResetAttackState()
    self.attack_state_table = {}
    
    for i = 1, #self.element_table do
        self.attack_state_table[ i ] = { state = ATTACK_STATE_Waiting, attack_timer = 0.0, it_can_attack = false, cool_down_timer = Group.ATTACK_MODE_COOL_DOWN_ATTACK_TIMER, waiting_position = Vector:new( 0.0, 0.0 ) }
    end
end

function Group:ApplyAttackFormation( dt )
    self:ComputeMergedEnemyCircle()
    
    if self.attack_strategy == ATTACK_STRATEGY_WaitToSurround then
        if self.attack_surround_state == SURROUND_FindArena then
            self.attack_arena = self.coordinator:GetAreaOutsideOf( REGION_TYPE_Forest, Group.ATTACK_MODE_ARENA_SIZE )
            self.attack_arena_last_position = self.attack_arena.center
            self.slot_table = self:ArrangeSlotsInCircle( Group.ATTACK_MODE_WAITING_ENEMY_SLOT_COUNT, 0 )
            self:ResetSearchForEnemy()
            self:ChooseBestSlots( Group.ATTACK_MODE_WAITING_ENEMY_SLOT_COUNT )
            self.attack_surround_state = SURROUND_WaitForEnemy
        elseif self.attack_surround_state == SURROUND_WaitForEnemy then
            local further_away_slot_index = self:GetFurtherAwaySlotIndex( self.attack_arena.center, self.attack_arena.radius, true )
    
            if ( further_away_slot_index ~= -1 and math.abs( self.attack_last_further_away_slot_index - further_away_slot_index ) > 1 ) then
                self:DispatchSlotsToElements( self.attack_arena.center, self.attack_arena.radius, further_away_slot_index, Group.ATTACK_MODE_WAITING_ENEMY_SLOT_COUNT )
                self:ResetAttackStrategyPhase()
                self.attack_last_further_away_slot_index = further_away_slot_index
                self.attack_arena_last_position = self.attack_arena.center
            elseif self.attack_arena_last_position:isNearby( 15.0, self.attack_arena.center ) then
                self:ApplySlotsToRelativePositions()
                self:ResetAttackStrategyPhase()
                self.attack_arena_last_position = self.attack_arena.center
            end
            
            for i, element in ipairs( self.element_table ) do
                local slot_position = self.attack_arena.center + self.element_relative_position_table[ self.order_table[ i ] ]
                local distance_to_slot = ( element.current_position - slot_position ):r()
                
                if self.attack_strategy_phase_table[ self.order_table[ i ] ].state == WAIT_TO_SURROUND_GoToSlots then
                    if self.attack_arena_is_moving then
                        if distance_to_slot >= 20.0 then
                            element:GoTo( slot_position, MOVE_Recal )
                        else
                            element:StopSoftly()
                        end
                    else
                        element:GoTo( slot_position, distance_to_slot >= 50.0 and MOVE_Walk or MOVE_FastRecal )
                        self.attack_strategy_phase_table[ self.order_table[ i ] ].state = WAIT_TO_SURROUND_TakePlaces
                    end
                elseif self.attack_strategy_phase_table[ self.order_table[ i ] ].state == WAIT_TO_SURROUND_TakePlaces then                    
                    if distance_to_slot <= 50.0 then
                        if distance_to_slot <= 1.0 then
                            element.current_position = slot_position
                            element:Stop()
                            self.attack_strategy_phase_table[ self.order_table[ i ] ].state = WAIT_TO_SURROUND_AimAtEnemy
                        else
                            element:GoTo( slot_position, MOVE_Recal )
                        end
                    end
                elseif self.attack_strategy_phase_table[ self.order_table[ i ] ].state == WAIT_TO_SURROUND_AimAtEnemy then
                    element:LookAt( self.attack_arena.center )
                    self.attack_strategy_phase_table[ self.order_table[ i ] ].state = WAIT_TO_SURROUND_TurnTowardEnemy
                elseif self.attack_strategy_phase_table[ self.order_table[ i ] ].state == WAIT_TO_SURROUND_TurnTowardEnemy then
                    if IsAlmostEqual( element.current_angle, element.desired_angle, 0.01 ) then
                        self.attack_strategy_phase_table[ self.order_table[ i ] ].state = WAIT_TO_SURROUND_WaitForEnemy
                    end
                elseif self.attack_strategy_phase_table[ self.order_table[ i ] ].state == WAIT_TO_SURROUND_WaitForEnemy then
                    -- Wait
                end
            end
            
            if self.attack_arena_can_move then
                if ( self.enemy_formation_circle.center - self.attack_arena.center ):r() > self.attack_arena.radius + 200.0 then
                    self:MoveArenaTowardAttackedGroup( 50.0, dt )
                else                    
                    self.attack_arena_is_moving = false
                end
            else
                if self:CheckIfAllElementsAreWaiting() then
                    self.attack_arena_can_move = true
                end
            end
        
            if self:GetEnemyPercentageInsideArena() >= Group.ATTACK_MODE_MIN_PERCENTAGE_ENEMY_INSIDE_ARENA then
                self:DumpSlotToNavigationPath()
                self:PlaceElementsAroundCircle()
                self:PlanNavigationFromTo( self.navigation_path_point_table, self.slot_table )
                self:ApplyNavigationPlan( self.attack_arena.radius )
                self:ResetAttackStrategyPhase()
                
                self.coordinator:OnGroupAttacking( self.group_id, self.enemy_group_id )
                self.attack_surround_state = SURROUND_TakePlace
            end
        elseif self.attack_surround_state == SURROUND_TakePlace then
            self:FollowPathPlan( dt )
            
            local it_has_someone_left_doing_path_find = false
            
            for _, phase in ipairs( self.attack_strategy_phase_table ) do
                if phase.state ~= WAIT_TO_SURROUND_Attack  then
                    it_has_someone_left_doing_path_find = true
                    break
                end
            end
            
            if it_has_someone_left_doing_path_find then
                self:ApplyNavigationPlan( self.attack_arena.radius )
            else
                self.attack_surround_state = SURROUND_InPlace
            end
        elseif self.attack_surround_state == SURROUND_InPlace then
            local from_slot_table = self:ArrangeSlotsInDoubleCircles( Group.ATTACK_MODE_WAITING_ENEMY_SLOT_COUNT, 0 )
            
            for i, slot in ipairs( self.slot_table ) do
                from_slot_table[ i ].element_index = slot.element_index
            end
            
            local to_slot_table = self:ArrangeSlotsInDoubleCircles( Group.ATTACK_MODE_WAITING_ENEMY_SLOT_COUNT, 0 )
            
            for i, _ in ipairs( self.slot_table ) do
                if from_slot_table[ i ].element_index ~= -1 then
                    to_slot_table[ from_slot_table[ i ].link_to[ 3 ] ].element_index = from_slot_table[ i ].element_index
                    to_slot_table[ i ].element_index = -1
                end
            end
            
            self.navigation_path_point_table = from_slot_table
            self.slot_table = to_slot_table
            self:PlanNavigationFromTo( from_slot_table, to_slot_table )
            self:ApplyNavigationPlan( self.attack_arena.radius * 0.8 )
            self:ResetAttackStrategyPhase()
            
            for i = 1, #self.element_table do
                self.attack_strategy_phase_table[ i ].timer = math.random() * 0.7
            end
            
            self.attack_surround_state = SURROUND_GetCloser
        elseif self.attack_surround_state == SURROUND_GetCloser then
            self:FollowPathPlan( dt )
            
            local it_has_someone_left_doing_path_find = false
            
            for _, phase in ipairs( self.attack_strategy_phase_table ) do
                if phase.state ~= WAIT_TO_SURROUND_Attack  then
                    it_has_someone_left_doing_path_find = true
                    break
                end
            end
            
            if it_has_someone_left_doing_path_find then
                self:ApplyNavigationPlan( self.attack_arena.radius * 0.8 )
            else
                self:MatchElementsToOpponents()
                self.attack_surround_state = SURROUND_Attack
            end
        elseif self.attack_surround_state == SURROUND_Attack then
            self:UpdateAttackStrategy( dt )
        end
    elseif self.attack_strategy == ATTACK_STRATEGY_FollowToSurround then
        if self:CheckIfEnemyIsMoving() then
            self:ComputeClosestPositionsFromMovingEnemyGroup( dt )
        end
        
        self:MoveElementsToMovingEnemyGroup()
    end
end

function Group:FollowPathPlan( dt )
    for i, element in ipairs( self.element_table ) do
        if self.attack_strategy_phase_table[ self.order_table[ i ] ].timer ~= -1 and self.attack_strategy_phase_table[ self.order_table[ i ] ].timer > 0.0 then
            self.attack_strategy_phase_table[ self.order_table[ i ] ].timer = self.attack_strategy_phase_table[ self.order_table[ i ] ].timer - dt
        else
            if self.attack_strategy_phase_table[ self.order_table[ i ] ].state == WAIT_TO_SURROUND_GoToSlots then
                local slot_position = self.attack_arena.center + self.element_relative_position_table[ self.order_table[ i ] ]
                local distance_to_slot = ( element.current_position - slot_position ):r()
                if not self:CheckIfElementIsDoneWithPathFind( i ) then
                    if distance_to_slot > 50.0 then
                        element:GoTo( slot_position, MOVE_Run )
                    else
                        element:Stop()
                    end
                else
                    if distance_to_slot > 1.0 then
                        element:GoTo( slot_position, distance_to_slot >= 50.0 and MOVE_Walk or MOVE_FastRecal )
                    else
                        element.current_position = element.desired_position
                        element:Stop()
                        
                        element:LookAt( self.attack_arena.center )
                        self.attack_strategy_phase_table[ self.order_table[ i ] ].state = WAIT_TO_SURROUND_AimAtEnemy
                    end
                end
            elseif self.attack_strategy_phase_table[ self.order_table[ i ] ].state == WAIT_TO_SURROUND_AimAtEnemy then
                if IsAlmostEqual( element.current_angle, element.desired_angle, 0.01 ) then
                    self.attack_strategy_phase_table[ self.order_table[ i ] ].state = WAIT_TO_SURROUND_Attack
                end
            elseif self.attack_strategy_phase_table[ self.order_table[ i ] ].state == WAIT_TO_SURROUND_Attack then
            end
        end
    end
    
    local it_has_someone_left_doing_path_find = false
    
    for _, phase in ipairs( self.attack_strategy_phase_table ) do
        if phase.state ~= WAIT_TO_SURROUND_Attack  then
            it_has_someone_left_doing_path_find = true
            break
        end
    end
end

function Group:ArrangeSlotsInCircle( slot_count, id_shift )
  local angle_inc = 2 * math.pi / slot_count
  local slot_table = {}
  for index = 1, slot_count do
      slot_table[ index ] = { id = LeftBitShift( index, id_shift ), element_index = -1, position = Vector:new( math.cos( index * angle_inc ), math.sin( index * angle_inc ) ):norm(), link_to = { ( ( index - 2 ) % slot_count ) + 1, ( ( index ) % slot_count ) + 1 } }
  end
  
  return slot_table
end

function Group:ArrangeSlotsInDoubleCircles( per_circle_slot_count, id_shift )
    local double_slot_table = {}
    double_slot_table = self:ArrangeSlotsInCircle( per_circle_slot_count, id_shift )
    
    local angle_inc = 2 * math.pi / per_circle_slot_count
    for index = 1, per_circle_slot_count do
        local current_index = per_circle_slot_count + index
        double_slot_table[ current_index ] = { id = LeftBitShift( current_index, id_shift ), element_index = -1, position = Vector:new( math.cos( index * angle_inc ), math.sin( index * angle_inc ) ):norm(), link_to = { per_circle_slot_count + ( ( index - 2 ) % per_circle_slot_count ) + 1, per_circle_slot_count + ( ( index ) % per_circle_slot_count ) + 1 } }
    end
    
    for index = 1, #double_slot_table do
        table.insert( double_slot_table[ index ].link_to, ( index <= per_circle_slot_count ) and ( per_circle_slot_count + index ) or ( index - per_circle_slot_count ) )
    end
    
    return double_slot_table
end

function Group:ChooseBestSlots( slot_count )
    local further_away_slot_index = self:GetFurtherAwaySlotIndex( self.attack_arena.center, self.attack_arena.radius, true )
    
    if further_away_slot_index ~= -1 then
        self:DispatchSlotsToElements( self.attack_arena.center, self.attack_arena.radius, further_away_slot_index, slot_count )
        self.attack_last_further_away_slot_index = further_away_slot_index
    end
end

function Group:GetFurtherAwaySlotIndex( center_position, area_radius, it_save_last_force )
    local force_sum = Vector:new( 0, 0 )
    local closest_distance = -1
    local closest_index = -1
    
    for _, enemy in ipairs( self.enemy_table ) do     
        local element_to_group_center_vector = center_position - enemy.current_position
        if element_to_group_center_vector:r() > area_radius then
            force_sum = force_sum + element_to_group_center_vector:norm()
        end
    end
    
    if force_sum:r() == 0.0 then
        force_sum = self.last_search_force
    end
    
    if force_sum:r() > 0.0 then
        force_sum = force_sum:norm()
        
        if it_save_last_force then
            self.last_search_force = force_sum
        end
    
        local force_position = center_position + force_sum * area_radius
        
        for i, slot in ipairs( self.slot_table ) do
            local current_slot_position = center_position + slot.position * area_radius
            local current_distance = ( force_position - current_slot_position ):r()
            
            if closest_index == -1 or current_distance < closest_distance then
                closest_index = i
                closest_distance = current_distance
            end
        end
    end
    
    return closest_index
end

function Group:DispatchSlotsToElements( center_position, area_radius, slot_index, slot_count )
    --local element_searching_count = #self.element_table
    --local sorted_element_table = {}
    --local slot_position = center_position + self.slot_table[ slot_index ].position * area_radius
    
    --for i, _ in ipairs( self.element_table ) do
    --    sorted_element_table[ i ] = i
    --end
    
    --table.sort( sorted_element_table, function( a, b ) local a_distance = ( self.element_table[ a ].current_position - slot_position ):r() local b_distance = ( self.element_table[ b ].current_position - slot_position ):r() return a_distance > b_distance end )
    
    --for index = 1, slot_count do
    --    self.slot_table[ index ].element_index = -1
    --end
    
    --local ordered_slot_index_table = self:GetOrderedSlotIndexTable( slot_position, center_position, area_radius, slot_count )
    --for i, sorted_index in ipairs( sorted_element_table ) do
    --    local closest_slot_index = self:FindClosestFreeSlotInTable( self.element_table[ sorted_index ].current_position, ordered_slot_index_table, element_searching_count, center_position, area_radius )
    --    self.slot_table[ closest_slot_index ].element_index = sorted_index
    --    self.element_relative_position_table[ self.order_table[ sorted_index ] ] = self.slot_table[ closest_slot_index ].position * area_radius
    --end
    
    local averaged_slot_distance_to_element_table = {}
    local slot_position = center_position + self.slot_table[ slot_index ].position * area_radius
    local ordered_slot_index_table = self:GetOrderedSlotIndexTable( slot_position, center_position, area_radius, slot_count )
    
    for i = 1, #self.element_table do
        local slot_index = ordered_slot_index_table[ i ]
        averaged_slot_distance_to_element_table[ i ] = 0.0
        for _, element in ipairs( self.element_table ) do
            averaged_slot_distance_to_element_table[ i ] = averaged_slot_distance_to_element_table[ i ] + ( ( center_position + self.slot_table[ slot_index ].position * area_radius ) - element.current_position ):r()
        end
        
        averaged_slot_distance_to_element_table[ i ] = averaged_slot_distance_to_element_table[ i ] / #self.element_table
    end
    
    local sorted_averaged_slot_distance_to_element_table = {}
    
    for i, _ in ipairs( averaged_slot_distance_to_element_table ) do
        sorted_averaged_slot_distance_to_element_table[ i ] = i
    end
    
    table.sort( sorted_averaged_slot_distance_to_element_table, function( a, b ) return averaged_slot_distance_to_element_table[ a ] > averaged_slot_distance_to_element_table[ b ] end )
    
    local slot_position = self.slot_table[ ordered_slot_index_table[ sorted_averaged_slot_distance_to_element_table[ 1 ] ] ].position
    local temp_table = {}
    for i = 1, #self.element_table do
        temp_table[ i ] = sorted_averaged_slot_distance_to_element_table[ i ]
    end
    table.sort( temp_table, function( a, b ) local distance_a = ( self.slot_table[ ordered_slot_index_table[ a ] ].position - slot_position ):r() local distance_b = ( self.slot_table[ ordered_slot_index_table[ b ] ].position - slot_position ):r() return distance_a < distance_b end )
    sorted_averaged_slot_distance_to_element_table = temp_table
    
    local element_has_been_placed_table = {}
    
    for i, _ in ipairs( self.element_table ) do
        element_has_been_placed_table[ i ] = false
    end
    
    for index = 1, slot_count do
        self.slot_table[ index ].element_index = -1
    end
    
    for i, sorted_slot in ipairs( sorted_averaged_slot_distance_to_element_table ) do
        local closest_distance = -1
        local closest_index = -1
        
        for j, element in ipairs( self.element_table ) do
            if not element_has_been_placed_table[ j ] then
                local current_distance = ( element.current_position - ( center_position + self.slot_table[ ordered_slot_index_table[ sorted_slot ] ].position * area_radius ) ):r()
                
                if closest_index == -1 or current_distance < closest_distance then
                    closest_index = j
                    closest_distance = current_distance
                end
            end
        end
        
        if closest_index ~= -1 then
            self.slot_table[ ordered_slot_index_table[ sorted_slot ] ].element_index = closest_index
            self.element_relative_position_table[ self.order_table[ closest_index ] ] = self.slot_table[ ordered_slot_index_table[ sorted_slot ] ].position * area_radius
            element_has_been_placed_table[ closest_index ] = true
        end
    end
end

function Group:DumpSlotToNavigationPath()
    for index, slot in ipairs( self.slot_table ) do
        self.navigation_path_point_table[ index ].element_index = slot.element_index
        self.navigation_path_point_table[ index ].position = slot.position
    end
end

function Group:PlaceElementsAroundCircle( new_slot_count )
    local current_slot_order = {}
    local half_slot_index = math.ceil( #self.element_table * 0.5 )
    local middle_slot_index = 1
    local slot_to_element_ratio = math.floor( #self.slot_table / #self.element_table )
    
    for index = 1, ( #self.slot_table + 1 ) do
        local current_index = ( index - 1 ) % #self.slot_table + 1
        local next_index = current_index % #self.slot_table + 1
        local current_slot = self.slot_table[ current_index ]
        local next_slot = self.slot_table[ next_index ]
        if current_slot.element_index == -1 and next_slot.element_index ~= -1 then
            middle_slot_index = ( ( current_index + half_slot_index - 1 ) % #self.slot_table ) + 1
            break
        end
    end
    
    local current_old_index = middle_slot_index
    local current_ordered_index = 1
    for i = 1, #self.slot_table do
        if self.slot_table[ current_old_index ].element_index ~= -1 then
            current_slot_order[ current_ordered_index ] = self.slot_table[ current_old_index ].element_index
            current_ordered_index = current_ordered_index + 1
        end
        
        current_old_index = ( current_old_index % #self.slot_table ) + 1
    end
    
    local current_slot_index = middle_slot_index
    current_ordered_index = 1
    for index = 1, #self.slot_table do
        if ( index - 1 ) % slot_to_element_ratio == 0 and current_ordered_index <=  #current_slot_order then
            self.slot_table[ current_slot_index ].element_index = current_slot_order[ current_ordered_index ]
            current_ordered_index = current_ordered_index + 1
        else
            self.slot_table[ current_slot_index ].element_index = -1
        end
        
        current_slot_index = ( current_slot_index % #self.slot_table ) + 1
    end
end

function Group:ApplySlotsToRelativePositions()
    for _, slot in ipairs( self.slot_table ) do
        if slot.element_index ~= - 1 then
            self.element_relative_position_table[ self.order_table[ slot.element_index ] ] = slot.position * self.attack_arena.radius
        end
    end
end

function Group:ApplyNavigationPlan( radius )
    for i, element in ipairs( self.element_table ) do
        if ( element.move_type == MOVE_Idle or element.move_type == MOVE_Aim ) and self.navigation_plan_table[ self.order_table[ i ] ].current_index <= #self.navigation_plan_table[ self.order_table[ i ] ].point_table then
            local next_index = self.navigation_plan_table[ self.order_table[ i ] ].point_table[ self.navigation_plan_table[ self.order_table[ i ] ].current_index ]
            
            if self.navigation_path_point_table[ next_index ].element_index == -1 then
                self.element_relative_position_table[ self.order_table[ i ] ] = self.navigation_path_point_table[ next_index ].position * radius
                
                for _, nav_point in ipairs( self.navigation_path_point_table ) do
                    if nav_point.element_index == i then
                        nav_point.element_index = -1
                    end
                end
                self.navigation_path_point_table[ next_index ].element_index = i
                self.navigation_plan_table[ self.order_table[ i ] ].current_index = self.navigation_plan_table[ self.order_table[ i ] ].current_index + 1
            end
        end
    end
end

function Group:CheckIfElementIsDoneWithPathFind( element_index )
    return self.navigation_plan_table[ self.order_table[ element_index ] ].current_index > #self.navigation_plan_table[ self.order_table[ element_index ] ].point_table
end

function Group:ComputeMergedEnemyCircle()
    if #self.enemy_table >= 1 then
        self.enemy_formation_circle = { radius = 30, center = self.enemy_table[ 1 ].current_position }
        for index = 2, #self.enemy_table do
            local current_enemy_circle = { radius = 30, center = self.enemy_table[ index ].current_position }
            self.enemy_formation_circle = MergeCircles( self.enemy_formation_circle, current_enemy_circle )
        end
    else
        self.enemy_formation_circle.radius = 0.0
        self.enemy_formation_circle.center = Vector:new( 0.0, 0.0 )
    end
end

function Group:CheckIfEnemyIsMoving()
    local averaged_velocity = Vector:new( 0.0, 0.0 )
    for _, enemy in ipairs( self.enemy_table ) do
        averaged_velocity = averaged_velocity + enemy:GetVelocity() * enemy.current_speed
    end
    
    averaged_velocity = averaged_velocity / #self.enemy_table
    
    return averaged_velocity:r() >= 5.0
end

function Group:ComputeClosestPositionsFromMovingEnemyGroup( dt )
    for i, element in ipairs( self.element_table ) do
        local handler = self.enemy_handling_element_table[ self.order_table[ i ] ]
        if handler.time_since_last_position_computed == -1 or handler.time_since_last_position_computed >= Group.ATTACK_MODE_MIN_TIME_TO_COMPUTE_CLOSEST_POSITION_TO_MOVING_ENEMY_GROUP then
            local group_to_element_direction = ( self.element_table[ i ].current_position - self.enemy_formation_circle.center )
            handler.closest_position_from_moving_enemy_group = self.enemy_formation_circle.center + group_to_element_direction:norm() * ( 30 + self.enemy_formation_circle.radius )
            
            local avoid_radius = 60
            local avoid_amplifier = 2
            local new_avoidance_vector = Vector:new( 0, 0 )
            for j = 1, i - 1 do
                if handler.closest_position_from_moving_enemy_group:isNearby( avoid_radius, self.enemy_handling_element_table[ self.order_table[ j ] ].closest_position_from_moving_enemy_group ) then
                    local avoid_vector = ( handler.closest_position_from_moving_enemy_group - self.enemy_handling_element_table[ self.order_table[ j ] ].closest_position_from_moving_enemy_group )
                    local unit_avoid_accel = avoid_vector:norm()
                    local avoid_multiplier = avoid_radius * avoid_amplifier / avoid_vector:r()
                    local avoid_accel = unit_avoid_accel * avoid_multiplier
                    new_avoidance_vector = new_avoidance_vector + avoid_accel
                end
            end
            
            handler.closest_position_from_moving_enemy_group = handler.closest_position_from_moving_enemy_group + new_avoidance_vector
            
            handler.time_since_last_position_computed = 0.0
        else
            handler.time_since_last_position_computed = handler.time_since_last_position_computed + dt
        end
    end
end

function Group:MoveElementsToMovingEnemyGroup()
    for i, element in ipairs( self.element_table ) do
        local current_distance = ( element.current_position - self.enemy_handling_element_table[ self.order_table[ i ] ].closest_position_from_moving_enemy_group ):r()
        
        if current_distance > Group.ATTACK_MODE_MIN_DISTANCE_TO_SLOT_AROUND_MOVING_ENEMY_GROUP then
            element:GoTo( self.enemy_handling_element_table[ self.order_table[ i ] ].closest_position_from_moving_enemy_group, current_distance < Group.ATTACK_MODE_MIN_DISTANCE_TO_SLOT_AROUND_MOVING_ENEMY_GROUP_TO_RECAL and MOVE_Recal or MOVE_Walk )
        else
            element:Stop()
        end
    end
end

function Group:GetEnemyPercentageInsideArena()
    local total_count = 0
    for _, enemy in ipairs( self.enemy_table ) do
        if enemy.current_position:isNearby( self.attack_arena.radius * 0.8, self.attack_arena.center ) then
            total_count = total_count + 1
        end
    end
    
    return total_count / #self.enemy_table
end

function Group:PlanNavigationFromTo( from_list, to_list )
    for i = 1, #from_list do
        local element_index = from_list[ i ].element_index
        local from_index = i
        local to_index = -1
        
        if element_index ~= -1 then
            for j = 1, #to_list do
                if to_list[ j ].element_index == element_index then
                    to_index = j
                    break
                end
            end
            
            local path = self:DijkstraFindPath( from_list, from_index, to_index )
            local shortest_path = self:GetShortestPath( path, to_index )
            
            self.navigation_plan_table[ self.order_table[ element_index ] ] = { point_table = shortest_path, current_index = 1 }
        end
    end
end

function Group:FindIndexFromId( graph, id )
    local index_to = -1
    
    for i, node in ipairs( graph ) do
        if node.id == id then
            index_to = i
            break
        end
    end
    
    return index_to
end

function Group:DijkstraFindPath( graph, index_from, index_to )    
    local distance = {}
    local prev = {}
    local q_list = {}
    
    distance[ index_from ] = 0
    prev[ index_from ] = -1
    
    for i, current_node in ipairs( graph ) do
        if i ~= index_from then
            distance[ i ] = -1
            prev[ i ] = -1
        end
        q_list[ i ] = { node = current_node, it_is_alive = true  }
    end
    
    local total = #q_list
    while total > 0 do
        local min_distance = -1
        local min_distance_index = -1
        total = 0
        
        for index = 1, #q_list do
            if q_list[ index ].it_is_alive then
                if distance[ index ] ~= -1 and ( min_distance_index == -1 or distance[index ] < min_distance ) then
                    min_distance_index = index
                    min_distance = distance[ index ]
                end
                total = total + 1
            end
        end
        
        local cached_index = min_distance_index
        q_list[ min_distance_index ].it_is_alive = false
        total = total - 1
        
        if cached_index == index_to then
            break
        end
        
        for index = 1, #graph[ cached_index ].link_to do
            local alt = distance[ cached_index ] + 1
            local current_distance = distance[ graph[ cached_index ].link_to[ index ] ]
            if current_distance == -1 or alt < current_distance then
                distance[ graph[ cached_index ].link_to[ index ] ] = alt
                prev[ graph[ cached_index ].link_to[ index ] ] = cached_index
            end
        end
    end
    
    return prev
end

function Group:GetShortestPath( path, target_index )
    local shortest_path = {}
    local position = target_index
    
    while path[ position ] ~= -1 do
        table.insert( shortest_path, 1, position )
        position = path[ position ]
    end
    
    return shortest_path
end

function Group:MoveArenaTowardAttackedGroup( desired_speed, dt )
    local acceleration = 0.02
    
    self.attack_arena_speed = self.attack_arena_speed + ( desired_speed - self.attack_arena_speed ) * acceleration
    
    local arena_to_target_direction = ( self.enemy_formation_circle.center - self.attack_arena.center ):norm()
    local temp_position = self.attack_arena.center + arena_to_target_direction * self.attack_arena_speed * dt
    
    self.attack_arena_is_moving = true
    
    if self.coordinator:IsInAllowedArea( REGION_TYPE_Forest, temp_position, Group.ATTACK_MODE_ARENA_SIZE ) then
        self.attack_arena.center = temp_position
        return
    end
    
    local temp_no_x = Vector:new( 0.0, arena_to_target_direction.y ):norm()
    temp_position = self.attack_arena.center + temp_no_x * self.attack_arena_speed * dt
        
    if self.coordinator:IsInAllowedArea( REGION_TYPE_Forest, temp_position, Group.ATTACK_MODE_ARENA_SIZE ) then
        self.attack_arena.center = temp_position
        return
    end
    
    local temp_no_y = Vector:new( arena_to_target_direction.x, 0.0 ):norm()
    temp_position = self.attack_arena.center + temp_no_y * self.attack_arena_speed * dt
            
    if self.coordinator:IsInAllowedArea( REGION_TYPE_Forest, temp_position, Group.ATTACK_MODE_ARENA_SIZE ) then
        self.attack_arena.center = temp_position
        return
    end
    
    self.attack_arena_is_moving = false
end

function Group:CheckIfAllElementsAreWaiting()
    for _, phase in ipairs( self.attack_strategy_phase_table ) do
        if phase.state ~= WAIT_TO_SURROUND_WaitForEnemy then
            return false
        end
    end
    
    return true
end

function Group:UpdateOpponentMatches( dt )
    for i, element in ipairs( self.element_table ) do
        local opponent = self.opponent_match_table[ self.order_table[ i ] ]
        
        if self.attack_state_table[ self.order_table[ i ] ].state == ATTACK_STATE_Waiting then
            opponent.timer = opponent.timer + dt
            
            if opponent.timer >= Group.ATTACK_MODE_SEARCH_NEW_OPPONENT_MAX_TIME then
                self:FindBestOpponentFor( i )
            end
        end
    end
end

function Group:UpdateAttackStrategy( dt )
    self:UpdateOpponentMatches( dt )
    self:UpdateMacroAttackStrategy( dt )
    self:UpdateHitTable( dt )
    
    for i, element in ipairs( self.element_table ) do
        if self.opponent_match_table[ self.order_table[ i ] ].index == -1 then
            if self.attack_state_table[ self.order_table[ i ] ].state == ATTACK_STATE_Waiting then
                element:LookAt( self.attack_arena.center )
                self:FindBestOpponentFor( i )
            else
                self:GoBackToWaitingState( i )
            end
            
            self.attack_state_table[ self.order_table[ i ] ].it_can_attack = false
        else
            local opponent_position = self.enemy_table[ self.opponent_match_table[ self.order_table[ i ] ].index ].current_position
            local distance_to_opponent = ( opponent_position - element.current_position ):r()
            
            if distance_to_opponent <= Group.ATTACK_MODE_MAX_ATTACKED_ENEMY_DISTANCE then
                self:UpdateElementAttack( i, dt )
            else
                if self.attack_state_table[ self.order_table[ i ] ].state == ATTACK_STATE_Waiting then
                    if distance_to_opponent > Group.ATTACK_MODE_MAX_ENEMY_DISTANCE then
                        self:FindBestOpponentFor( i )
                    else
                        element:LookAt( opponent_position )
                    end
                else
                    self:GoBackToWaitingState( i )
                end

                self.attack_state_table[ self.order_table[ i ] ].it_can_attack = false
            end
        end
    end
end

function Group:GoBackToWaitingState( index )
    local element = self.element_table[ index ]
    local slot_position = self.attack_state_table[ self.order_table[ index ] ].waiting_position
    local element_to_slot_distance = ( slot_position - element.current_position ):r()
    if element_to_slot_distance <= 1.0 then
        element.current_position = element.desired_position
        element:Stop()
        
        self.attack_state_table[ self.order_table[ index ] ].state = ATTACK_STATE_Waiting
    end
end

function Group:UpdateElementAttack( index, dt )
    local hit_position = 15.0
    local current_state = self.attack_state_table[ self.order_table[ index ] ].state
    local enemy_position = self.enemy_table[ self.opponent_match_table[ self.order_table[ index ] ].index ].current_position
    local element = self.element_table[ index ]
    local element_to_enemy_vector = ( enemy_position - element.current_position )
    local element_to_enemy_direction = element_to_enemy_vector:norm()
    local element_to_enemy_distance = element_to_enemy_vector:r()
    local target_position = ( element_to_enemy_distance > hit_position ) and ( element.current_position + element_to_enemy_direction * ( element_to_enemy_distance - hit_position ) ) or element.current_position
    local slot_position = self.attack_state_table[ self.order_table[ index ] ].waiting_position
    
    if current_state == ATTACK_STATE_Waiting then
        if self.attack_state_table[ self.order_table[ index ] ].it_can_attack then
            self.attack_state_table[ self.order_table[ index ] ].attack_timer = self.attack_state_table[ self.order_table[ index ] ].attack_timer + dt
            
            if self.attack_state_table[ self.order_table[ index ] ].attack_timer >= Group.ATTACK_MODE_MIN_ATTACK_TIMER then
                self.attack_state_table[ self.order_table[ index ] ].waiting_position = math.random() >= 0.5 and element.current_position or target_position
                self.attack_state_table[ self.order_table[ index ] ].state = ATTACK_STATE_Going
            end
        else
            self.attack_state_table[ self.order_table[ index ] ].attack_timer = 0.0
        end
        
        element:LookAt( enemy_position )
    elseif current_state == ATTACK_STATE_Going then
        if element_to_enemy_distance > hit_position then
            element:GoToAndLookAt( target_position, enemy_position, element_to_enemy_distance > 50.0 and MOVE_Walk or MOVE_FastRecal )
        else
            element.current_position = element.desired_position
            element:Stop()
            
            self.attack_state_table[ self.order_table[ index ] ].state = ATTACK_STATE_Hitting
        end
    elseif current_state == ATTACK_STATE_Hitting then
        self:ElementHitsEnemy( index, self.opponent_match_table[ self.order_table[ index ] ].index )
        self.attack_state_table[ self.order_table[ index ] ].it_can_attack = false
        self.attack_state_table[ self.order_table[ index ] ].cool_down_timer = 0.0
        element:GoToAndLookAt( slot_position, enemy_position, MOVE_FastRecal )
        self.attack_state_table[ self.order_table[ index ] ].state = ATTACK_STATE_Backing
    elseif current_state == ATTACK_STATE_Backing then
        local element_to_slot_distance = ( slot_position - element.current_position ):r()
        if element_to_slot_distance <= 1.0 then
            element.current_position = element.desired_position
            element:Stop()
            
            element:ForceAngleToLookAtPosition( enemy_position )
            self.attack_state_table[ self.order_table[ index ] ].state = ATTACK_STATE_Waiting
        end
    end
end

function Group:UpdateMacroAttackStrategy( dt )
    local max_attacking_element_count = 1
    local attacking_element_table = {}
    local attack_candidat_table = {}
    
    for i, element_state in ipairs( self.attack_state_table ) do
        if element_state.it_can_attack then
            table.insert( attacking_element_table, i )
        end
        
        element_state.cool_down_timer = element_state.cool_down_timer + dt
    end
    
    for i, element in ipairs( self.element_table ) do
        local opponent_index = self.opponent_match_table[ self.order_table[ i ] ].index
        if opponent_index ~= -1 then
            local distance_to_opponent = ( self.enemy_table[ opponent_index ].current_position - element.current_position ):r()
            
            if distance_to_opponent < Group.ATTACK_MODE_MAX_ATTACKED_ENEMY_DISTANCE and self.attack_state_table[ self.order_table[ i ] ].cool_down_timer >= Group.ATTACK_MODE_COOL_DOWN_ATTACK_TIMER then
                table.insert( attack_candidat_table, i )
            end
        end
    end
    
    if #attacking_element_table < max_attacking_element_count and #attack_candidat_table > 0 then
        local random_candidat_index = self.order_table[ attack_candidat_table[ math.random( 1, #attack_candidat_table ) ] ]
        self.attack_state_table[ random_candidat_index ].it_can_attack = true
    end
end

function Group:ElementHitsEnemy( element_index, enemy_index )
    table.insert( self.attack_hit_table, { position = self.enemy_table[ enemy_index ].current_position, scale = Group.ATTACK_MODE_HIT_RENDER_MAX_SIZE, timer = 0.0 } )
    self.coordinator:OnElementHittingAnother( self.group_id, element_index, self.enemy_group_id, enemy_index )
end

function Group:FindBestOpponentFor( element_index )
    local element = self.element_table[ self.order_table[ element_index ] ]
    local closest_index = -1
    local closest_distance = -1
    
    for i, enemy in ipairs( self.enemy_table ) do
        local current_distance = ( enemy.current_position - element.current_position ):r()
        
        if current_distance <= Group.ATTACK_MODE_MAX_ENEMY_DISTANCE and ( closest_index == -1 or current_distance < closest_distance ) then
            closest_index = i
            closest_distance = current_distance
        end
    end
    
    self.opponent_match_table[ self.order_table[ element_index ] ] = { index = closest_index, timer = 0.0 }
end

function Group:MatchElementsToOpponents()
    self.opponent_match_table = {}
    for index = 1, #self.element_table do
        self:FindBestOpponentFor( index )
    end
end

function Group:UpdateHitTable( dt )
    for i = 1, #self.attack_hit_table do
        local hit = self.attack_hit_table[ i ]
        
        hit.timer = hit.timer + dt
        
        if hit.timer >= Group.ATTACK_MODE_HIT_RENDER_MAX_TIME then
            self.attack_hit_table[ i ] = nil
            i = i - 1
        else
            hit.scale = Group.ATTACK_MODE_HIT_RENDER_MAX_SIZE * ( 1.0 - hit.timer / Group.ATTACK_MODE_HIT_RENDER_MAX_TIME )
        end
    end
end

function Group:ElementGivesHitTo( giving_element_index, taking_element_index )
    print( giving_element_index .. " gives hit to " .. taking_element_index )
end

function Group:ElementTakesHitFrom( giving_element_index, taking_element_index )
    --self.defense_state_table[ self.order_table[ taking_element_index ] ].state = DEFENSE_STATE_HitBack
    --self.defense_state_table[ self.order_table[ taking_element_index ] ].attacking_index = giving_element_index
end

-- Defense mode

function Group:StartDefenseMode( group_id, group_to_defend_from )
    self:ChangeGroupMode( GROUP_Defense )
    
    self.enemy_group_id = group_id
    self.defense_from_attacking_group = group_to_defend_from
    
    for _, enemy in ipairs( group_to_defend_from.element_table ) do
        table.insert( self.enemy_table, enemy )
    end
    
    if group_leader ~= nil and not group_to_defend_from.leader:IsDummy() then
        table.insert( self.enemy_table, group_leader )
    end
    
    self:SpreadElementsOntoCircle()
end

function Group:SpreadElementsOntoCircle()
    self.slot_table = {}
    local slot_count = #self.element_table
    local angle_inc = 2 * math.pi / slot_count
    for index = 1, slot_count do
        self.slot_table[ index ] = { id = LeftBitShift( index, 0 ), element_index = -1, position = Vector:new( math.cos( index * angle_inc ), math.sin( index * angle_inc ) ):norm(), link_to = { ( ( index - 2 ) % slot_count ) + 1, ( ( index ) % slot_count ) + 1 } }
    end
    
    local minimum_radius = #self.element_table * 30.0 * 0.5
    local center_position = self.leader.current_position
    local slot_state = {}
    
    for index = 1, #self.slot_table do
        slot_state[ index ] = true
    end
        
    for index = 1, #self.element_table do   
        local closest_distance = -1
        local closest_index = -1
        
        for j, slot in ipairs( self.slot_table ) do
            if slot_state[ j ] then
                local current_distance = ( ( center_position + slot.position * minimum_radius ) - self.element_table[ self.order_table[ index ] ].current_position ):r()
                
                if closest_index == -1 or current_distance < closest_distance then
                    closest_index = j
                    closest_distance = current_distance
                end
            end
        end
        
        if closest_index ~= -1 then
            self.slot_table[ closest_index ].element_index = index
            slot_state[ closest_index ] = false
        end
    end
    
    for _, slot in ipairs( self.slot_table ) do
        if slot.element_index ~= - 1 then
            self.element_relative_position_table[ self.order_table[ slot.element_index ] ] = slot.position * minimum_radius
        end
    end
    
    self.defense_last_group_position = self.leader.current_position
end

function Group:ApplyDefenseFormation( dt )
    self:UpdateCentralPosition( dt )
    self:UpdateElementsOrientation( dt )
    
    local all_elements_under_threshold = true
    
    for i, element in ipairs( self.element_table ) do
        if self.defense_state_table[ self.order_table[ i ] ].state == DEFENSE_STATE_Waiting then
            local desired_position = self.defense_last_group_position + self.element_relative_position_table[ self.order_table[ i ] ]
            local distance_to_target = ( element.current_position - desired_position ):r()
            local look_at_position = self.enemy_table[ self.defense_info_table[ self.order_table[ i ] ].closest_enemy_index ].current_position
            
            if distance_to_target > 1.0 then
                if distance_to_target > 50.0 then
                    all_elements_under_threshold = false
                    element:GoTo( desired_position, MOVE_Walk )
                else
                    element:GoToAndLookAt( desired_position, look_at_position, MOVE_Recal )
                end
            else
                local forced_angle = nil
                local delta_x = ( look_at_position.x - element.current_position.x )
                local delta_y = ( look_at_position.y - element.current_position.y )
                
                if math.abs( delta_x ) > 0.001 or math.abs( delta_y ) > 0.001 then
                    forced_angle = math.atan2( delta_y, delta_x )
                end
                
                if forced_angle ~= nil and IsAlmostEqual( element.sight_angle, forced_angle, 0.01 ) then
                    element.current_angle = forced_angle
                    element:Stop()
                else
                    element.current_speed = 0.0
                    element.current_angle = forced_angle ~= nil and forced_angle or element.current_angle
                    element:LookAt( look_at_position )
                end
            end
        elseif self.defense_state_table[ self.order_table[ i ] ].state == DEFENSE_STATE_HitBack then
            local enemy_index = self.defense_state_table[ self.order_table[ i ] ].attacking_index
            
            if enemy_index ~= -1 then
                local enemy_position = self.enemy_table[ enemy_index ].current_position
                element:LookAt( enemy_position )
            end
        end
    end
    
    if not all_elements_under_threshold then
        self.defense_last_group_position = self.leader.current_position
    end
end

function Group:UpdateCentralPosition( dt )    
    if not self.leader.current_position:isNearby( self.defense_from_attacking_group.attack_arena.radius, self.defense_from_attacking_group.attack_arena.center ) then
        self:JoiningLeader()
    end
end

function Group:JoiningLeader()
     self.defense_last_group_position = self.leader.current_position
     self:ResetDefenseState()
end

function Group:UpdateElementsOrientation( dt )
    local half_angle = Group.DEFENSE_MODE_HALF_SIGHT_ANGLE * math.pi / 180
    self.defense_info_table = {}
    
    for i, element in ipairs( self.element_table ) do
        local closest_index = -1
        local closest_distance = -1
        local circle_center_to_element_angle = WrapAngle( ( element.current_position - self.defense_last_group_position ):norm():ang() )
        
        for j, enemy in ipairs( self.enemy_table ) do
            local element_to_enemy_angle = WrapAngle( ( enemy.current_position - element.current_position ):norm():ang() )
            
            if ( circle_center_to_element_angle - half_angle ) <= element_to_enemy_angle and ( circle_center_to_element_angle + half_angle ) >= element_to_enemy_angle then
                local current_distance = WrapAngle( circle_center_to_element_angle - element_to_enemy_angle )
                
                if closest_index == -1 or current_distance < closest_distance then
                    closest_index = j
                    closest_distance = current_distance
                end
            end
        end
        
        if closest_index == -1 then
            for j, enemy in ipairs( self.enemy_table ) do
                local current_distance = ( enemy.current_position - element.current_position ):r()
                
                if closest_index  == -1 or current_distance < closest_distance then
                    closest_index = j
                    closest_distance = current_distance
                end
            end
        end
        
        self.defense_info_table[ self.order_table[ i ] ] = { closest_enemy_index = closest_index }
    end
end

function Group:ResetDefenseState()
    self.defense_state_table = {}
    
    for i = 1, #self.element_table do
        self.defense_state_table[ i ] = { state = DEFENSE_STATE_Waiting, position = Vector:new( 0.0, 0.0 ), attacking_index = -1 }
    end
end