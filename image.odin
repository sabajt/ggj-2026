package main

import "core:strings"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

Atlas :: struct {
    Name: string,
    Width: int, Height: int,
    Images: [dynamic]Atlas_Image
}
Atlas_Image :: struct {
    Name: string,
    X: int, Y: int, W: int, H: int,
    TrimOffsetX: int, TrimOffsetY: int,
    UntrimmedWidth: int, UntrimmedHeight: int
}
sprite_atlas: Atlas
sprite_atlas_map: map[string]Atlas_Image

load_image :: proc(name: string) -> ^sdl.Surface
{
    // TODO: error check
    cs := strings.clone_to_cstring(name, context.temp_allocator)
    surface := img.Load(cs)
    if surface == nil {
        sdl.Log("image failed to load")
    }
    return surface
}
