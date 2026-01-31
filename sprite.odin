package main

import "core:math"
import "core:fmt"

sprites := [dynamic]Sprite {}
clear_sprites :: proc() { clear(&sprites) }

Anchor :: enum {
    center,
	bottom_left
}

Sprite :: struct {
    name: string,
    tf: Blendable_Transform,
    col: [4]f32,
    anchor: Anchor
}

add_sprite :: proc(name: string, pos: [2]f32 = 0, rot: f32 = 0, scale: [2]f32 = 1, col: [4]f32 = 1, anchor: Anchor = .center) -> int
{
    length := len(sprites)
    spr := Sprite {name, tf(pos, rot, scale), col, anchor}
	append(&sprites, spr)
    return length
}

update_sprite :: proc(
    spr: ^Sprite, 
    pos: Maybe([2]f32) = nil, 
    rot:  Maybe(f32) = nil, 
    scale:  Maybe([2]f32) = nil, 
    col:  Maybe([4]f32) = nil, 
    anchor:  Maybe(Anchor) = nil)
{
    snap_sprite_to_latest_frame(spr)

    if val, ok := pos.?; ok { spr.tf.cur.pos = val }
    if val, ok := rot.?; ok { spr.tf.cur.rot = val }
    if val, ok := scale.?; ok { spr.tf.cur.scale = val }
    if val, ok := col.?; ok { spr.col = val }
    if val, ok := anchor.?; ok { spr.anchor = val }
}

snap_sprite_to_latest_frame :: proc(spr: ^Sprite)
{
    spr.tf.last = spr.tf.cur
}

spr_size :: proc(spr: Sprite) -> [2]f32
{
    img := sprite_atlas_map[spr.name]
    size := spr.tf.cur.scale * { f32(img.W), f32(img.H) } 
    return { math.abs(size.x), math.abs(size.y) }
}

create_gpu_sprite :: proc(spr: Sprite, dt: f32) -> GPU_Sprite
{ 
    atlas_image := sprite_atlas_map[spr.name]
    w := f32(atlas_image.UntrimmedWidth)
    h := f32(atlas_image.UntrimmedHeight)

    anchor: [2]f32
    switch spr.anchor {
    case .center:
        anchor = {0, 0}
    case .bottom_left: 
        anchor = {0.5, -0.5}
    }

    blended_tf := blend_fit_res_letterbox(spr.tf, dt)

    return GPU_Sprite {
        position = {blended_tf.pos.x, blended_tf.pos.y, 1},
        rotation = blended_tf.rot,
        scale = blended_tf.scale * {w, -h},
        anchor = anchor,
        tex_u = f32(atlas_image.X) / f32(sprite_atlas.Width),
        tex_v = f32(atlas_image.Y) / f32(sprite_atlas.Height),
        tex_w = f32(atlas_image.UntrimmedWidth) / f32(sprite_atlas.Width),
        tex_h = f32(atlas_image.UntrimmedHeight) / f32(sprite_atlas.Height),
        color = spr.col,
    }
}
