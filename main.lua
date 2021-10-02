local game_state = require('game_state')
local render = require('render')

local state

function love.load()
  render.setup()
  state = game_state.new()
end

function love.draw()
  if state then
    render.render_game(state)
  end
end

function love.resize()

end

function love.keypressed(key)

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