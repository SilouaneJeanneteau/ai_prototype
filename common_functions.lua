require 'vector'

ACTION_None, ACTION_LookFront, ACTION_GoBack, ACTION_Turn = 0, 1, 2, 3
SUB_ACTION_None, SUB_ACTION_UTurn, SUB_ACTION_LookFront, SUB_ACTION_LeftTurn, SUB_ACTION_RightTurn, SUB_ACTION_DriftUTurn, SUB_ACTION_BigDriftUTurn = 0, 1, 2, 3, 4, 5, 6
MOVE_Idle, MOVE_SlowWalk, MOVE_Walk, MOVE_FastWalk, MOVE_Run, MOVE_Recal = 0, 1, 2, 3, 4, 5
FORMATION_Grouped, FORMATION_SingleLine, FORMATION_Count = 0, 1, 2
SEARCH_None, SEARCH_First, SEARCH_New = 0, 1, 2
LOCOMOTION_Position, LOCOMOTION_Trajectory = 0, 1
TRAJECTORY_Aiming, TRAJECTORY_Navigating = 0, 1
TRAJECTORY_POINT_VerySlow, TRAJECTORY_POINT_Slow, TRAJECTORY_POINT_Normal, TRAJECTORY_POINT_Stop = 0, 1, 2, 3

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