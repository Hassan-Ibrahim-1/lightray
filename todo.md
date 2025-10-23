# NEXT
render to framebuffer
how will this work. I don't want the user to have multiple
render passes that they create manually by renderer functions
there has to be a better way here. because if i bind a framebuffer
i'm going to have to do a render pass just for that framebuffer.

leave the engine running for a bit, i think there's a leak?
render times increase as it keeps going. i have no idea what that means.

figure out the math for the raytracer. don't rush
write a cpu software raytracer that can make beautiful things
translate engine.Scene into something easy to raytrace
parallelize the raytracer on the cpu
make it run using compute shaders
being able to do textures at some point would be nice
maybe use vulkan for hardware raytracing

if im acutally serious about graphics i should switch to vulkan
write after writing the cpu raytracer. do a c rewrite.

engine stuff
    - an easy way to move things around
    - compute shaders
    - make sure hot reloading works
    - an easy way to import models at runtime, an asset management system would be good here
    - figure out how to test the engine, or at least its sub parts

maybe?
    - an ecs would be interesting

raytracing stuff
    - be able to setup a scene using normal rendering
    - hit a key to ray trace the scene, the rt should be progressive. refer to sebastian lague's videos for this
    - understand rt math

first write a cpu software raytracer.
then move it over to a compute shader.

hardware raytracing with vulkan would also be nice

simd math

bounding box stuff

things i want to raytrace:
    a dark hallway
    a bunch of cubes in the air in a dark setting
    a cozy room with a fireplace
    an old car
    a fractal
    glass
    clouds
    see through jade / porcelain

------------------------------------------------------------------------------------------------------

visualize linear transformations to vectors, models, etc
draw a basic grid which should also be able to undergo transformations
be able to visualize vectors. draw them as arrows
drag vectors around using a mouse

# engine
get mouse interactions with world space objects to work properly
    - so basically just detect what actors the mouse intersects with and give that to the user

add more visual help to the engine
    * visualize any vector
    * draw points / small spheres anywhere

allocation visualizations - pretty much what jai has

lessen allocations for names in Scene

be able to delete added actors

# for rt
compute shaders

# TODO
rewrite engine
    -- update to 0.15
    - rework bad code
        ** resource API's (models, textures, meshes, shaders, etc).
             the user should be able to access the underlying data tho
        ** stop useless allocations in imgui.zig and just use a buffer
        ** rework mesh api to use DrawCommand instead of an optional
        * testing. figure out how to use valgrind to detect memory problems
            run mocks. isolate components. comptime interfaces to simulate things
            like input, imgui stuff, graphics, ...
            modules to test: renderer, scene, input, Camera, resources, editor, etc
        * better opengl diagnostics

uniform buffer objects
    * can store camera matrices
    * can store lighting data

# Now
-- drawing vectors

gizmo
    * be able to select an object
    * figure out the math to move it around
        - could test this out by moving the points

framebuffers
raytracing
-- mouse interactitons
testing

add tests
    * comptime interfaces for
        window, input, renderer, gpu resources

fix release builds

rt prereqs:
    testing
    gizmo

-- remove mesh from ResourcePool and make it copyable instead

for now just create new buffers for each spec.

move most development over to linux
    * mesa drivers are more strict, better to have to correct programs.
    * better debugging support

make debugging and profiling way easier, add diagnostics like draw call count, etc.
hook up opengl debug callbacks for linux.
add a way to debug opengl vbos, there should be something that can track what you send in
to a vbo. there should also be a naming system for gpu resources to keep track of stuff.
add a way to debug vao attribute pointers, pretty much anything opengl related.

i need good tooling.
apitrace
renderdoc
download amd profilers

I want these to be places where I can walk around in
dark backroom like hallways
an old library with a fireplace
trees, terrain
