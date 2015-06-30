require 'vector'
require 'group'

Coordinator = {
   identity = "Coordinator class"
}

function Coordinator:new()
   local instance = {}
   setmetatable( instance, self )
   self.__index = self

   instance.group_list = {}

   return instance
end

function Coordinator:Initialize()
	self.group_list = {}
end

function Coordinator:Register( new_group, leader )
	table.insert( self.group_list, Group:new( new_group, leader ) )
end

function Coordinator:OnAddToGroup( group_index )
    self.group_list[ group_index ]:OnAddElement()
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

function Coordinator:SetFormation( index, formation_type )
	self.group_list[ index ]:ChangeFormation( formation_type )
end

function Coordinator:UpdateRegion( region_list, dt )
	for group_index, group in ipairs( self.group_list ) do
		for _, region in ipairs( region_list ) do
	    	if region:IsInside( group.leader.current_position ) then
	    		self:SetFormation( group_index, FORMATION_SingleLine )
	    	else
	    		self:SetFormation( group_index, FORMATION_Grouped )
	    	end
	   end
	end
end