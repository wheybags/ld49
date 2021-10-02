local render = {}

local constants = require("constants")
local game_state = require("game_state")
local serpent = require('extern.serpent')

render._load_tex = function(path)
  local tex = love.graphics.newImage(path)
  tex:setFilter("nearest")
  return tex
end

render.setup = function()
  render.tileset = render._load_tex("gfx/tileset.png")
  render.player_idle = {render._load_tex("gfx/player_idle1.png"), render._load_tex("gfx/player_idle2.png")}

  render.tileset_quads = {}

  local w
  local h
  w, h = render.tileset:getDimensions()

  local idx = 0

  for y = 0, (h/constants.tile_size)-1 do
    for x = 0, (w/constants.tile_size)-1 do
      local quad = love.graphics.newQuad(x * constants.tile_size, y * constants.tile_size,
        constants.tile_size, constants.tile_size,
        render.tileset:getDimensions()
      )

      render.tileset_quads[idx] = quad
      idx = idx + 1
    end
  end

  if love.system.getOS() == "Windows" then
    local ffi = require("ffi")
    ffi.cdef[[
    int SetProcessDPIAware();
    ]]

    ffi.C.SetProcessDPIAware()
  end

  local _, _, flags = love.window.getMode()
  local width, height = love.window.getDesktopDimensions(flags.display)

  local usable_width = width * 0.8
  local usable_height = height * 0.8

  local target_tile_size = constants.screen_size

  local size = {target_tile_size[1] * constants.tile_size, target_tile_size[2] * constants.tile_size}
  render.scale = 1

  while true do
    local next_size = {size[1] * (render.scale+1), size[2] * (render.scale+1)}

    if next_size[1] > usable_width or next_size[2] > usable_height then
      break
    end

    render.scale = render.scale + 1
  end

  love.window.setMode(size[1] * render.scale, size[2] * render.scale)
end

render._draw_tile = function(x, y, tile_index)
  assert(render.tileset_quads[tile_index])

  love.graphics.draw(render.tileset,
                     render.tileset_quads[tile_index],
                     x * constants.tile_size * render.scale,
                     y * constants.tile_size * render.scale,
                     0, render.scale, render.scale)
end

render._draw_on_tile = function(x, y, image, rotation_deg)
  if rotation_deg == nil then rotation_deg = 0 end

  love.graphics.draw(image,
                     (x + 0.5) * constants.tile_size * render.scale,
                     (y + 0.5) * constants.tile_size * render.scale,
                     rotation_deg * 0.01745329, render.scale, render.scale,
                     constants.tile_size/2, constants.tile_size/2)
end

render._draw_rect_on_tile = function(x, y)

  love.graphics.rectangle('fill',
                          x * constants.tile_size * render.scale,
                          y * constants.tile_size * render.scale,
                          constants.tile_size/4 * render.scale, constants.tile_size/4 * render.scale)
end

render._draw_debug_segments = function(state)
  local segments = game_state.calculate_segments(state)

  for index, segment in pairs(segments) do
    math.randomseed(index)
    love.graphics.setColor(math.random(), math.random(), math.random())

    for _, pos in pairs(segment) do
      render._draw_rect_on_tile(pos[1], pos[2])
    end
  end

 love.graphics.setColor(1, 1, 1)
end

render._render_level = function(state, render_tick)
  for y = 0, state.height-1 do
    for x = 0, state.width-1 do
      render._draw_tile(x, y, game_state.index(state, x, y, state.dirt_layer))
    end
  end
  --for _, ball_pos in pairs(state.dirt_balls.bs) do
  --  render._draw_tile(ball_pos[1], ball_pos[2], constants.dirt_backslash)
  --end
  --for _, ball_pos in pairs(state.dirt_balls.fs) do
  --  render._draw_tile(ball_pos[1], ball_pos[2], constants.dirt_slash)
  --end


  for y = 0, state.height-1 do
    for x = 0, state.width-1 do
      render._draw_tile(x, y, game_state.index(state, x, y, state.bedrock_layer))

      local real_tile = game_state.index(state, x, y)
      if real_tile ~= constants.dirt_tile_id and real_tile ~= constants.bedrock_tile_id then
        render._draw_tile(x, y, real_tile)
      end
    end
  end

  if render_tick % 60 < 30 then
    render._draw_on_tile(state.player_pos[1], state.player_pos[2], render.player_idle[1])
  else
    render._draw_on_tile(state.player_pos[1], state.player_pos[2], render.player_idle[2])
  end
end

render.render_game = function(state, render_tick)
  local evaluated_state = game_state.evaluate(state)
  love.graphics.clear(16/255, 25/255, 28/255)
  render._render_level(evaluated_state, render_tick)

  --render._draw_debug_segments(evaluated_state)
end

return render