Sprite Scale Deform issue?

1. SV_VertexID + first_vertex (already fixed)
The commit a4c475b fixed this: on DirectX, SV_VertexID does not include the first_vertex offset (unlike Metal/Vulkan where it does). So the old first_vertex = batch_start * 6 caused the shader to always index from 0, reading the wrong sprite data for any non-first batch. This would produce wrong positions/scale = deformation.

2. letterbox_texture dimensions vs letterbox_resolution mismatch (likely still present)
This one looks problematic right now. The texture is created once at init:


// init.odin:183
width = u32(letterbox_resolution.x),
height = u32(letterbox_resolution.y),
But letterbox_resolution is recomputed every frame in update_resolutions. On Windows, CreateWindow with .FULLSCREEN may not report the actual monitor resolution until after the first event loop tick. So at init time GetWindowSize could return config.resolution = {1792, 1008} → letterbox_resolution = 3 × INTERNAL_RES = {1920, 1080}, but once the window is actually fullscreened (e.g., on a 2560×1440 monitor), update_resolutions yields letterbox_resolution = 4 × INTERNAL_RES = {2560, 1440}.

Now the blit does:


source = sdl.GPUBlitRegion {
    texture = letterbox_texture,
    w = u32(letterbox_resolution.x),  // 2560 — but texture is only 1920 wide!
    h = u32(letterbox_resolution.y)   // 1440 — but texture is only 1080 tall!
}
Reading a {2560, 1440} region from a {1920, 1080} texture. SDL likely clamps it, so only the upper-left {1920, 1080} portion has real content. The blit then scales that portion to fill the destination, making everything appear squished into a corner and scaled wrong.

3. HIGH_PIXEL_DENSITY + mixed logical/physical pixels
update_resolutions uses get_resolution() = GetWindowSize (logical pixels), while the blit uses get_resolution_pixels() = GetWindowSizeInPixels (physical pixels). On Mac Retina these differ by 2×, but the math works out. On Windows with fractional DPI (e.g., 125%, 150%), GetWindowSize can return values that don't divide evenly into INTERNAL_RES, making math.ceil in get_letterbox_res round to a larger multiple than expected — again causing the texture size to lag behind the computed letterbox_resolution.

Most actionable fix to try: explicitly set a viewport in render_internal matching the letterbox texture's actual creation size, or recreate the texture when letterbox_resolution changes. Right now there's no viewport set, so SDL defaults to the texture's physical dimensions — which may no longer match letterbox_resolution.