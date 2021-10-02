local game_state = {}

local levels = {
  require('levels.teach_climb_gap').layers[1]
}

game_state.new = function()
  local state = {
    width = 0,
    height = 0,
    data = 0,
  }

  game_state.load_level(state, 1)

  return state
end

game_state.load_level = function(state, level_index)
  local level_data = levels[level_index]

  state.width = level_data.width
  state.height = level_data.height
  state.data = level_data.data
end

game_state.index = function(level_data, x, y, data)
  if data == nil then data = level_data.data end

  assert(x >= 0 and x < level_data.width)
  assert(y >= 0 and y < level_data.height)

  local index = (x + y * level_data.width) + 1
  return data[index] - 1
end

return game_state