local game_state = {}

local constants = require("constants")
local serpent = require("extern.serpent")

local levels = {
  --require('levels.test').layers[1],
  --require('levels.teach_climb_gap').layers[1],
  require('levels.drop_block_path').layers[1],
}


game_state.slice = function(tbl, count)
  local sliced = {}

  for _, val in pairs(tbl) do
    if count > 0 then
      table.insert(sliced, val)
    end
    count = count - 1
  end

  return sliced
end

game_state.deepcopy = function(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[game_state.deepcopy(orig_key)] = game_state.deepcopy(orig_value)
        end
        setmetatable(copy, game_state.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

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

local eval_cache = {}

game_state.evaluate = function(state)
  local evaluate_recursive
  evaluate_recursive = function(moves)
    local cache_key = table.concat(moves, ',')

    if eval_cache[cache_key] then
      return game_state.deepcopy(eval_cache[cache_key])
    end

    if #moves == 0 then
      return
      {
        width = state.width,
        height = state.height,
        data = {unpack(state.data)},
        player_pos = {unpack(state.player_pos)},
        dead = false,
      }
    end

    local tails = game_state.slice(moves, #moves - 1)
    local evaluated = evaluate_recursive(tails)
    local direction = moves[#moves]


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

    if not game_state._coord_valid(evaluated, evaluated.player_pos[1], evaluated.player_pos[2]) then
      return nil
    end

    -- Digging
    local dug = false
    local target_tile_id = game_state.index(evaluated, evaluated.player_pos[1], evaluated.player_pos[2])
    if game_state._tile_is_solid(target_tile_id) then
      if target_tile_id == constants.dirt_tile_id then
        dug = true
        game_state._set(evaluated, evaluated.player_pos[1], evaluated.player_pos[2], constants.deleted_placeholder_tile)
      else
        return nil
      end
    end

    -- special case for walking down stairs
    if not dug and (direction == "left" or direction == "right") and
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

    game_state._try_drop_rocks(evaluated)

    for y = 0, evaluated.height-1 do
      for x = 0, evaluated.width-1 do
        local tile_id = game_state.index(evaluated, x, y)
        if tile_id == constants.deleted_placeholder_tile then
          game_state._set(evaluated, x, y, constants.air_tile_id)
        end
      end
    end

    if game_state._tile_is_solid(game_state.index(evaluated, evaluated.player_pos[1], evaluated.player_pos[2])) then
      evaluated.dead = true
    end

    eval_cache[cache_key] = game_state.deepcopy(evaluated)

    return evaluated
  end

  return evaluate_recursive(state.moves)
end

game_state.calculate_segments = function(state)
  local assignments = {}
  local next_id = 0

  local assigned

  for y = 0, state.height-1 do
    for x = 0, state.width-1 do
      local tile_id = game_state.index(state, x, y)

      assigned = nil
      if x > 0 then
        if tile_id == game_state.index(state, x - 1, y) then
          assigned = assignments[(x-1) .. ',' .. y].id
        end
      end

      if y > 0 then
        if tile_id == game_state.index(state, x, y - 1) then
          local new_assigned = assignments[x .. ',' .. (y-1)].id

          if assigned ~= nil and assigned ~= new_assigned then
            for key, value in pairs(assignments) do
              if value.id == assigned then
                assignments[key].id = new_assigned
              end
            end
          end

          assigned = new_assigned
        end
      end

      if assigned == nil then
        assigned = next_id
        next_id = next_id + 1
      end

      assignments[x .. ',' .. y] = {pos = {x, y}, id = assigned}
    end
  end

  local buckets_by_id = {}
  for key, value in pairs(assignments) do
    if buckets_by_id[value.id] == nil then
      buckets_by_id[value.id] = {}
    end

    buckets_by_id[value.id][key] = value.pos
  end

  local final_buckets = {}
  for _, bucket in pairs(buckets_by_id) do
    table.insert(final_buckets, bucket)
  end

  return final_buckets
end

game_state._try_drop_rocks = function(state)
  local segments = game_state.calculate_segments(state)
  local did_move = true

  while did_move do
    did_move = false
    for seg_index, segment in pairs(segments) do
      local segment_tile
      for _, point in pairs(segment) do
        segment_tile = game_state.index(state, point[1], point[2])
        break
      end
      assert(segment_tile)

      if game_state._tile_is_solid(segment_tile) and segment_tile ~= constants.deleted_placeholder_tile then
        local can_fall = true
        for _, point in pairs(segment) do
          if point[1] == 0 or point[1] == (state.width-1) or point[2] == 0 or point[2] == (state.height-1) then
            can_fall = false
            break
          end

          local at_bottom_of_segment = segment[point[1] .. ',' .. (point[2] + 1)]
          if not at_bottom_of_segment then
            local tile_under = game_state.index(state, point[1], point[2] + 1)
            if game_state._tile_is_solid(tile_under) then
              can_fall = false
              break
            end
          end
        end

        if can_fall then
          did_move = true
          for _, point in pairs(segment) do
            game_state._set(state, point[1], point[2], constants.air_tile_id)
          end
          local new_segment = {}
          for _, point in pairs(segment) do
            local new_point = {point[1], point[2] + 1}
            game_state._set(state, new_point[1], new_point[2], segment_tile)
            new_segment[new_point[1] .. ',' .. new_point[2]] = new_point
          end
          segments[seg_index] = new_segment
        end
      end
    end
  end
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