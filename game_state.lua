local game_state = {}

local constants = require("constants")
local serpent = require("extern.serpent")

local levels = {
  require('levels.teach_climb_gap').layers[1]
}

game_state.new = function()
  local state = {
    width = 0,
    height = 0,
    data = 0,
    player_pos = {0, 0},
    moves = {},
  }

  game_state.load_level(state, 1)

  return state
end

game_state.load_level = function(state, level_index)
  local level_data = levels[level_index]

  state.width = level_data.width
  state.height = level_data.height
  state.data = {unpack(level_data.data)}

  for y = 0, level_data.height-1 do
    for x = 0, level_data.width-1 do
      if game_state.index(state, x, y) == constants.spawn_tile_id then
        state.player_pos = {x, y}
        game_state._set(state, x, y, constants.air_tile_id)
      end
    end
  end
end

game_state.index = function(level_data, x, y)
  assert(x >= 0 and x < level_data.width)
  assert(y >= 0 and y < level_data.height)

  local index = (x + y * level_data.width) + 1
  return level_data.data[index] - 1
end

game_state._set = function(level_data, x, y, tile_id)
  assert(tile_id ~= nil)
  assert(x >= 0 and x < level_data.width)
  assert(y >= 0 and y < level_data.height)

  local index = (x + y * level_data.width) + 1
  level_data.data[index] = tile_id + 1
end

game_state.evaluate = function(state)
  local evaluated = {
    width = state.width,
    height = state.height,
    data = {unpack(state.data)},
    player_pos = {unpack(state.player_pos)},
    dead = false,
  }

  for _, direction in pairs(state.moves) do
    if evaluated.dead then
      return nil
    end

    local move = {0, 0}

    if direction == "right" then
      move[1] = 1
    elseif direction == "left" then
      move[1] = -1
    elseif direction == "down" then
      move[2] = 1
    elseif direction == "up" then
      move[2] = -1
    end

    local grip = game_state.has_grip(evaluated)
    if direction == "up" and not grip.beside then
      return nil
    end

    local on_solid_ground = game_state._coord_valid(evaluated, evaluated.player_pos[1], evaluated.player_pos[2] + 1) and game_state._tile_is_solid(game_state.index(evaluated, evaluated.player_pos[1], evaluated.player_pos[2] + 1))

    -- don't allow jumping off a wall hang
    if (direction == "left" and not grip.below_left and not on_solid_ground) or
       (direction == "right" and not grip.below_right and not on_solid_ground)
    then
      return nil
    end

    evaluated.player_pos[1] = evaluated.player_pos[1] + move[1]
    evaluated.player_pos[2] = evaluated.player_pos[2] + move[2]

    if not game_state._coord_valid(evaluated, evaluated.player_pos[1], evaluated.player_pos[2]) or
       game_state._tile_is_solid(game_state.index(evaluated, evaluated.player_pos[1], evaluated.player_pos[2]))
    then
      return nil
    end

    -- special case for walking down stairs
    if (direction == "left" or direction == "right") and
       game_state._coord_valid(evaluated, evaluated.player_pos[1], evaluated.player_pos[2] + 1) and not game_state._tile_is_solid(game_state.index(evaluated, evaluated.player_pos[1], evaluated.player_pos[2] + 1)) and
       game_state._coord_valid(evaluated, evaluated.player_pos[1], evaluated.player_pos[2] + 2) and game_state._tile_is_solid(game_state.index(evaluated, evaluated.player_pos[1], evaluated.player_pos[2] + 2))
    then
      evaluated.player_pos[2] = evaluated.player_pos[2] + 1
    end

    while true do
      if (evaluated.player_pos[2] + 1) >= evaluated.height then
        evaluated.dead = true
        break
      end

      if game_state._tile_is_solid(game_state.index(evaluated, evaluated.player_pos[1], evaluated.player_pos[2] + 1)) then break end

      local new_grip = game_state.has_grip(evaluated)
      if new_grip.beside or new_grip.below then
        break
      end

      evaluated.player_pos[2] = evaluated.player_pos[2] + 1
    end
  end

  return evaluated
end

game_state._direction_to_vector = function(direction)
  local move = {0, 0}

  if direction == "right" then
    move[1] = 1
  elseif direction == "left" then
    move[1] = -1
  elseif direction == "down" then
    move[2] = 1
  elseif direction == "up" then
    move[2] = -1
  end

  return move
end

game_state._tile_is_solid = function(tile_id)
  return tile_id ~= constants.air_tile_id and tile_id ~= constants.loot_tile_id and tile_id ~= constants.level_end_tile_id
end

game_state._coord_valid = function(state, x, y)
  return x >= 0 and x < state.width and y >= 0 and y < state.height
end

game_state.has_grip = function(state_evaluated)
  local grip_at_offset = function(offX, offY)
    local x = state_evaluated.player_pos[1] + offX
    local y = state_evaluated.player_pos[2] + offY

    return x >= 0 and x < state_evaluated.width and y >= 0 and y < state_evaluated.height and game_state._tile_is_solid(game_state.index(state_evaluated, x, y))
  end

  local result = {
    left = grip_at_offset(-1, 0),
    right = grip_at_offset(1, 0),
    below_left = grip_at_offset(-1, 1),
    below_right = grip_at_offset(1, 1),
  }

  result.beside = result.left or result.right
  result.below = result.below_left or result.below_right

  return result
end

game_state.move = function(state, direction)
  table.insert(state.moves, direction)

  if not game_state.evaluate(state) then
    table.remove(state.moves, #state.moves)
  else
    --print(serpent.line(state.moves))
  end
end

game_state.undo = function(state)
  if #state.moves > 0 then
    table.remove(state.moves, #state.moves)
    --print(serpent.line(state.moves))
  end
end

return game_state