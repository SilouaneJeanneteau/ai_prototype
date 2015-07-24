require 'vector'
require 'group'

Coordinator = {
   identity = "Coordinator class"
}

function Coordinator:new( new_region_list )
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   instance.group_list = {}
   instance.region_list = new_region_list

   return instance
end

function Coordinator:Initialize()
	self.group_list = {}
end

function Coordinator:Register( new_group, leader, group_id )
	table.insert( self.group_list, Group:new( new_group, leader, self, group_id ) )
end

function Coordinator:OnAddToGroup( group_index )
    self.group_list[ group_index ]:OnAddElement( #self.group_list[ group_index ].element_table )
end

function Coordinator:OnRemoveFromGroup( group_index, element_index )
    self.group_list[ group_index ]:OnRemoveElement( element_index )
end

function Coordinator:Update( dt )
	for _, group in ipairs( self.group_list ) do
		group:Update( dt )
   	end
end

function Coordinator:Draw()
    for _, group in ipairs( self.group_list ) do
		group:Draw()
   	end
end

function Coordinator:DrawEffects()
    for _, group in ipairs( self.group_list ) do
		group:DrawEffects()
   	end
end

function Coordinator:SetFormation( index, formation_type )
	self.group_list[ index ]:ChangeFormation( formation_type )
end

function Coordinator:UpdateRegion( dt )
	for group_index, group in ipairs( self.group_list ) do
		for _, region in ipairs( self.region_list ) do
	    	if region:IsInside( group.leader.current_position ) and region:GetType() == REGION_TYPE_Forest then
	    		self:SetFormation( group_index, FORMATION_SingleLine )
	    	else
	    		self:SetFormation( group_index, FORMATION_Grouped )
	    	end
	   end
	end
end

function Coordinator:GetAreaOutsideOf( region_type_to_avoid, minimum_size )
    local allowed_area = self:GetAllowedArea( region_type_to_avoid )
    local best_area = { center = Vector:new( love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.5 ), radius = minimum_size }
    
    best_area.center.x = math.random( allowed_area.position.x + minimum_size, allowed_area.position.x + allowed_area.extent.x - minimum_size )
    best_area.center.y = math.random( allowed_area.position.y + minimum_size, allowed_area.position.y + allowed_area.extent.y - minimum_size )
    
    return best_area
end

function Coordinator:IsInAllowedArea( region_type_to_avoid, position, minimum_size )
    local allowed_area = self:GetAllowedArea( region_type_to_avoid )
    
    return position.x >= allowed_area.position.x + minimum_size and position.x <= allowed_area.position.x + allowed_area.extent.x - minimum_size
        and position.y >= allowed_area.position.y + minimum_size and position.y <= allowed_area.position.y + allowed_area.extent.y - minimum_size
end

function Coordinator:GetAllowedArea( region_type_to_avoid )
    local allowed_area = { position = Vector:new( 0.0, 0.0 ), extent = Vector:new( love.graphics.getWidth(), love.graphics.getHeight() ) }
    
    for _, region in ipairs( self.region_list ) do
        if region.type == region_type_to_avoid then
            local right_size_x = region.position.x + region.size
            local left_size_x = region.position.x
            local bottom_size_y = region.position.y + region.size
            if right_size_x >= allowed_area.position.x and right_size_x <= allowed_area.position.x + allowed_area.extent.x then
                allowed_area.extent.x = allowed_area.extent.x - ( right_size_x + 1 - allowed_area.position.x )
                allowed_area.position.x = right_size_x + 1
            elseif left_size_x >= allowed_area.position.x and left_size_x <= allowed_area.position.x + allowed_area.extent.x then
                    allowed_area.extent.x = allowed_area.extent.x - ( ( allowed_area.position.x + allowed_area.extent.x ) - left_size_x )
            elseif bottom_size_y >= allowed_area.position.y and bottom_size_y <= allowed_area.position.y + allowed_area.extent.y then
                allowed_area.extent.y = allowed_area.extent.y - ( bottom_size_y + 1 - allowed_area.position.y )
                allowed_area.position.y = bottom_size_y + 1
            else
                local up_size_y = region.position.y
                if up_size_y >= allowed_area.position.y and up_size_y <= allowed_area.position.y + allowed_area.extent.y then
                    allowed_area.extent.y = allowed_area.extent.y - ( ( allowed_area.position.y + allowed_area.extent.y ) - up_size_y )
                end
            end
        end
    end
    
    return allowed_area
end

function Coordinator:OnGroupAttacking( attacking_group_id, attacked_group_id )
    self.group_list[ attacked_group_id ]:StartDefenseMode( attacking_group_id, self.group_list[ attacking_group_id ] )
end

function Coordinator:OnElementHittingAnother( giving_group_index, giving_element_index, taking_group_index, taking_element_index )
    self.group_list[ giving_group_index ]:ElementGivesHitTo( giving_element_index, taking_element_index )
    self.group_list[ taking_group_index ]:ElementTakesHitFrom( giving_element_index, taking_element_index )
end

function Coordinator:OnRemoveEnemyFromGroup( group_index, enemy_index )
    self.group_list[ group_index ]:OnRemoveEnemy( enemy_index )
end