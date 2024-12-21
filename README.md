# Simple Game Engine

Building a simple game engine in Odin using the Sokol library for handling graphics

## Examples

In the `define.odin` file you can modify the following variables to see different examples

```
bg_color :: example_<name>_bg_color 
game_init :: example_<name>_init
game_render :: example_<name>_render
game_event :: example_<name>_event
```
As of right now, the only examples are `pong` and `house`


## Instructions

1. NOTE: This only needs to be done the first time you download or modify sokol 
   First you need the sokol libraries so cd into the `sokol-odin/sokol` directory and run either: 
   ```
   # for windows
   ./build_clibs_windows.cmd
   # for macos
   ./build_clibs_macos.sh
   # for linux
   ./build_clibs_linux.sh
   ```

2. Then cd back out to the root directory
3. Download sokol-shdc for the platform you're using from [here](https://github.com/floooh/sokol-tools-bin/tree/master/bin)
4. NOTE: This only needs to be done whenever the quad_shader.glsl file is modified
   Run the following command to compile the shaders:
   ```
   ./sokol-shdc -i src/quad_shader.glsl -o src/quad_shader.shader.odin --slang glsl430:hlsl5:metal_macos -f sokol_odin
   ```
5. You can now compile or run this like a regular Odin project
   ```
   odin run src -debug
   # or to build
   odin build src 
   ```



