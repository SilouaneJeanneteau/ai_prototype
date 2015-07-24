require 'vector'
require 'boid'
require 'bait'
require 'player'
require 'region'
require 'coordinator'
require 'dummy'

local attack_boid_count = 8
local defense_boid_count = 3
local boid_list_list = { {} }
local bait_list = {}
local region_list = {}
local player
local coordinator
local it_can_spawn = true
local it_can_remove = true
local dummy = nil

function love.load()
  if arg[#arg] == "-debug" then require("mobdebug").start() end
	math.randomseed( os.time() )
	love.window.setMode( 1280, 720, { resizable = false, vsync = true } )
	love.graphics.setBackgroundColor( 100, 100, 100 )

	InitSimulation()
end

function InitSimulation()
	boid_list_list = {}
	region_list = {}

	player = Player:new(
		230,
		50
		)
	
	dummy = Dummy:new( 900.0, 400.0 )

	CreateRandomBoid( 1, attack_boid_count )
	CreateBoidInsideArea( 2, defense_boid_count, { center = player.current_position, extent = Vector:new( 100.0, 100.0 ) } )

	coordinator = Coordinator:new( region_list )
	coordinator:Register( boid_list_list[ 1 ], dummy, 1 )
	coordinator:Register( boid_list_list[ 2 ], player, 2 )
	coordinator.group_list[ 1 ]:StartAttackMode( 2, coordinator.group_list[ 2 ].element_table, coordinator.group_list[ 2 ].leader )
	coordinator.group_list[ 2 ]:ChangeFormationRadius( 30 )

	CreateRegion( -100, -100, 300, { r = 10, g = 205, b = 25, a = 255 } )
end

function love.draw()
	for _, region in ipairs( region_list ) do
	  region:draw()
	end

	for _, bait in ipairs( bait_list ) do
	  bait:draw()
	end
	
	coordinator:Draw()

	for _, boid_list in ipairs( boid_list_list ) do
		for i, boid in ipairs( boid_list ) do
			boid:draw( i )
		end
	end
	
    dummy:draw()

    player:draw()
	
	coordinator:DrawEffects()
end

function CreateRandomBoid( index, count )
	CreateBoidInsideArea( index, count, { center = Vector:new( love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.5 ), extent = Vector:new( love.graphics.getWidth() * 0.5, love.graphics.getHeight() * 0.5 ) } )
end

function CreateBoidInsideArea( index, count, area )
    boid_list_list[ index ] = {}
	for i = 1, count do
		table.insert( boid_list_list[ index ], Boid:new(
			math.random( area.center.x - area.extent.x, area.center.x + area.extent.x ),
			math.random( area.center.y - area.extent.y, area.center.y + area.extent.y ),
			math.random() * 2.0 * math.pi
			)
		)
	end
end

function CreateRegion( x, y, size, color )
	table.insert( region_list, Region:new( x, y, size, color, REGION_TYPE_Forest ) )
end

function love.update( dt )
	coordinator:Update( dt )
	coordinator:UpdateRegion( dt )

	for _, boid_list in ipairs( boid_list_list ) do
		for i, boid in ipairs( boid_list ) do
			boid:Update( dt, boid_list )
        end
	end

	player:Update( dt )

    local left_mouse_click = love.mouse.isDown( "l" )
    local right_mouse_click = love.mouse.isDown( "r" )
	local group_index = 2
	local enemy_group_table = { 1 }
	if left_mouse_click or right_mouse_click then
		if it_can_spawn and 1 + #boid_list_list[ group_index ] <= Group.MAX_SLOT_PER_CIRCLE then
			table.insert( boid_list_list[ group_index ], Boid:new(
				love.mouse.getX(),
				love.mouse.getY(),
				math.random() * 2.0 * math.pi
				)
			)
			
			local boid_count = #boid_list_list[ group_index ]
			if right_mouse_click then
			    boid_list_list[ group_index ][ boid_count ]:SetCapacityToSlow()
			end

			coordinator:OnAddToGroup( group_index )

			coordinator.group_list[ 1 ]:OnAddEnemy( boid_list_list[ group_index ][ boid_count ] )

			it_can_spawn = false
		end
	else
		it_can_spawn = true
	end
	
	if love.keyboard.isDown( "p" ) then
        if it_can_remove then
            table.remove( boid_list_list[ group_index ], 1 )
            coordinator:OnRemoveFromGroup( group_index, 1 )
            
            for _, enemy_group_index in ipairs( enemy_group_table ) do
                coordinator:OnRemoveEnemyFromGroup( enemy_group_index, 1 )
            end
        end
        
        it_can_remove = false
    else
        it_can_remove = true
    end

	if love.keyboard.isDown( "r" ) then
		InitSimulation()
	end
end
