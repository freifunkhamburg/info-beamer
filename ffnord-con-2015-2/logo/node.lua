gl.setup(1280, 720)

background = resource.load_image("logo.png")

function node.render()
    gl.clear(0.1, 0.1, 0.1, 1)
    background:draw(0, 0, WIDTH, HEIGHT)
end
