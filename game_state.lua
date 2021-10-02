local game_state = {}

local constants = require("constants")

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
    player_pos = {unpack(state.player_pos)}
  }

  for _, direction in pairs(state.moves) do
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

    evaluated.player_pos[1] = evaluated.player_pos[1] + move[1]
    evaluated.player_pos[2] = evaluated.player_pos[2] + move[2]
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

game_state.move = function(state, direction)
  local state_evaluated = game_state.evaluate(state)

  local move = game_state._direction_to_vector(direction)
  local new_pos = {state_evaluated.player_pos[1] + move[1], state_evaluated.player_pos[2] + move[2]}

  if game_state.index(state_evaluated, new_pos[1], new_pos[2]) == constants.air_tile_id then
    table.insert(state.moves, direction)
  end
end

game_state.undo = function(state)
  if #state.moves > 0 then
    table.remove(state.moves, #state.moves)
  end
end

return game_state