require 'vector'

ACTION_None, ACTION_LookFront, ACTION_GoBack, ACTION_Turn = 0, 1, 2, 3
SUB_ACTION_None, SUB_ACTION_UTurn, SUB_ACTION_LookFront, SUB_ACTION_LeftTurn, SUB_ACTION_RightTurn, SUB_ACTION_DriftUTurn, SUB_ACTION_BigDriftUTurn = 0, 1, 2, 3, 4, 5, 6
MOVE_Idle, MOVE_SlowWalk, MOVE_Walk, MOVE_FastWalk, MOVE_Run, MOVE_Recal, MOVE_FastRecal, MOVE_Aim = 0, 1, 2, 3, 4, 5, 6, 7
FORMATION_Grouped, FORMATION_SingleLine, FORMATION_Count = 0, 1, 2
SEARCH_None, SEARCH_First, SEARCH_New = 0, 1, 2
LOCOMOTION_Position, LOCOMOTION_Trajectory = 0, 1
TRAJECTORY_Aiming, TRAJECTORY_Navigating = 0, 1
TRAJECTORY_POINT_VerySlow, TRAJECTORY_POINT_Slow, TRAJECTORY_POINT_Normal, TRAJECTORY_POINT_Stop = 0, 1, 2, 3
GROUP_Follow, GROUP_Attack, GROUP_Defense = 0, 1, 2
ATTACK_STRATEGY_WaitToSurround, ATTACK_STRATEGY_FollowToSurround = 0, 1
WAIT_TO_SURROUND_GoToSlots, WAIT_TO_SURROUND_TakePlaces, WAIT_TO_SURROUND_AimAtEnemy, WAIT_TO_SURROUND_TurnTowardEnemy, WAIT_TO_SURROUND_WaitForEnemy, WAIT_TO_SURROUND_Attack = 0, 1, 2, 3, 4, 5
SURROUND_FindArena, SURROUND_WaitForEnemy, SURROUND_TakePlace, SURROUND_InPlace, SURROUND_GetCloser, SURROUND_Attack = 0, 1, 2 , 3
REGION_TYPE_OpenField, REGION_TYPE_Forest = 0, 1

function WrapAngle( angle )
   local result = angle
   local pi_two = 2 * math.pi

   while result > math.pi do
      result = result - pi_two
   end

   while result < -math.pi do
      result = result + pi_two
   end

   return result
end

function DebugText( text )
   love.graphics.setColor( 255, 0, 0, 255 )
   love.graphics.print( text, 10, 200 )
end

function ShallowCopy( orig )
    local orig_type = type( orig )
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs( orig ) do
            copy[ orig_key ] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

function DeepCopy( orig )
    local orig_type = type( orig )
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[ DeepCopy( orig_key ) ] = DeepCopy( orig_value )
        end
        setmetatable( copy, DeepCopy( getmetatable( orig ) ) )
    else
        copy = orig
    end
    return copy
end

function IsAlmostEqual( number1, number2, epsilon )
    local difference

    difference = number1 - number2

    return ( ( difference * difference ) <= ( epsilon * epsilon ) )
end

function ProjectPointOntoLine( line1, line2, point )
    local m = ( line2.x - line1.x ) == 0 and 0 or ( line2.y - line1.y ) / ( line2.x - line1.x )
    local b = line1.y - ( m * line1.x )
    local x = ( m * point.y + point.x - m * b ) / ( m * m + 1 )
    local y = ( m * m * point.y + m * point.x + b ) / ( m * m + 1 )
    
    return Vector:new( x, y )
end

function AngleBetweenVectors( vector1, vector2 )
    return math.acos( vector2:dot( vector1 ) / ( vector2:r() * vector1:r() ) )
end

function MergeCircles( circle1, circle2 )
    local result = { radius = 0.0, center = Vector:new( 0.0, 0.0 ) }
    local center_diff = circle2.center - circle1.center
    local length_squ = center_diff:dot( center_diff )
    local radius_diff = circle2.radius - circle1.radius
    local radius_diff_squ = radius_diff * radius_diff
    
    if radius_diff_squ >= length_squ then
        result = radius_diff >= 0.0 and circle2 or circle1
    else
        local length = math.sqrt( length_squ )
        if length > 0.0 then
            local coeff = ( length + radius_diff ) / ( 2.0 * length )
            result.center = circle1.center + center_diff * coeff
        else
            result.center = circle1.center
        end
        
        result.radius = 0.5 * ( length + circle1.radius + circle2.radius )
    end
    
    return result
end

function LeftBitShift( number, shift )
    return number * ( 2 ^ shift )
end