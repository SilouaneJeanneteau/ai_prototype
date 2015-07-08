require 'vector'

ACTION_None, ACTION_LookFront, ACTION_GoBack, ACTION_Turn = 0, 1, 2, 3
SUB_ACTION_None, SUB_ACTION_UTurn, SUB_ACTION_LookFront, SUB_ACTION_LeftTurn, SUB_ACTION_RightTurn, SUB_ACTION_DriftUTurn, SUB_ACTION_BigDriftUTurn = 0, 1, 2, 3, 4, 5, 6
MOVE_Idle, MOVE_SlowWalk, MOVE_Walk, MOVE_FastWalk, MOVE_Run, MOVE_Recal = 0, 1, 2, 3, 4, 5
FORMATION_Grouped, FORMATION_SingleLine, FORMATION_Count = 0, 1, 2
SEARCH_None, SEARCH_First, SEARCH_New = 0, 1, 2
LOCOMOTION_Position, LOCOMOTION_Trajectory = 0, 1
TRAJECTORY_Aiming, TRAJECTORY_Navigating = 0, 1

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