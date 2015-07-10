require 'vector'
require 'boid'
require 'bait'
require 'player'
require 'region'
require 'coordinator'

local boid_count = 1
local boid_list_list = { {} }
local bait_list = {}
local region_list = {}
local player
local coordinator
local it_can_spawn = true

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
		0.5 * love.graphics.getWidth(),
		0.5 * love.graphics.getHeight()
		)

	CreateRandomBoid( 1, boid_count )

	--CreateRandomBoid( 2, boid_count )

	coordinator = Coordinator:new()
	coordinator:Register( boid_list_list[ 1 ], player )
	--coordinator:Register( boid_list_list[ 2 ], boid_list_list[ 1 ][ 1 ] )

	CreateRegion( -300, 0, 800, { r = 10, g = 205, b = 25, a = 255 } )
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

   player:draw()
end

function CreateRandomBoid( index, count )
	boid_list_list[ index ] = {}
	for i = 1, count do
		table.insert( boid_list_list[ index ], Boid:new(
			math.random() * love.graphics.getWidth(),
			math.random() * love.graphics.getHeight(),
			math.random( 30 ) - 15,
			math.random( 30 ) - 15
			)
		)
	end
end

function CreateRegion( x, y, size, color )
	table.insert( region_list, Region:new( x, y, size, color ) )
end

function love.update( dt )
	coordinator:Update( dt )
	coordinator:UpdateRegion( region_list, dt )

	for _, boid_list in ipairs( boid_list_list ) do
		for i, boid in ipairs( boid_list ) do
			boid:Update( dt, boid_list )
   
            --print( i .. " " .. ( boid.move_type == MOVE_Idle and "Idle" or boid.move_type == MOVE_FastWalk and "Fast Walk"  or boid.move_type == MOVE_Walk and "Walk" or boid.move_type == MOVE_Run and "Run" or boid.move_type == MOVE_SlowWalk and "Slow Walk" or "Recal" ) )
		end
	end

	player:Update( dt )

	if love.mouse.isDown( "l" ) then
	    local group_index = 1
		if it_can_spawn and 1 + #boid_list_list[ group_index ] <= Group.MAX_SLOT_PER_CIRCLE then
			table.insert( boid_list_list[ group_index ], Boid:new(
				love.mouse.getX(),
				love.mouse.getY(),
				math.random( 30 ) - 15,
				math.random( 30 ) - 15
				)
			)
			
			local boid_count = #boid_list_list[ group_index ]
			if ( boid_count % 2 ) == 0 then
			    boid_list_list[ group_index ][ boid_count ]:SetCapacityToSlow()
			end

			coordinator:OnAddToGroup( group_index )

			it_can_spawn = false
		end
	else
		it_can_spawn = true
	end

	if love.keyboard.isDown( "r" ) then
		InitSimulation()
	end
end
