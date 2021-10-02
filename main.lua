local game_state = require('game_state')
local render = require('render')

local state
local render_tick = 0

function love.load()
  render.setup()
  state = game_state.new()
end

function love.draw()
  if state then
    render.render_game(state, render_tick)
  end
end

function love.resize()

end

function love.keypressed(key)
  if key == "right" or key == "left" or key == "up" or key == "down" then
    game_state.move(state, key)
  elseif key == "z" then
    game_state.undo(state)
  end
end


function love.mousemoved(x,y)

end

function love.wheelmoved(x,y)

end

function love.mousepressed(x,y,button)

end

function love.quit()

end

local fixed_update = function()
  render_tick = render_tick + 1
end

local accumulatedDeltaTime = 0
function love.update(deltaTime)
  accumulatedDeltaTime = accumulatedDeltaTime + deltaTime

  local tickTime = 1/60

  while accumulatedDeltaTime > tickTime do
    fixed_update()
    accumulatedDeltaTime = accumulatedDeltaTime - tickTime
  end
end