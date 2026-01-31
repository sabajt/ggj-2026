package main

import ttf "vendor:sdl3/ttf"
import "core:fmt"
import "core:strings"

LETTER_SPACING := f32(75)

font_sfns_mono : ^ttf.Font
font_sfns_mono_2 : ^ttf.Font
text_engine : ^ttf.TextEngine
text_items : [dynamic]TTF_Text_Item

TTF_Text_Item :: struct {
    raw_string : string,
    text : ^ttf.Text,
    geo_data : ^Text_Geometry_Data,
    pos : [2]f32,
    color: [4]f32,
    active: bool
}

Text_Geometry_Data :: struct {
    vertices : [dynamic]Text_Vertex,
    indices : [dynamic]u32
}

next_text_id := 0
add_text_item :: proc(raw_string: string, screenpos: [2]f32 = {0, 0}, color: [4]f32 = 1) -> int
{
    geo_data := new(Text_Geometry_Data)
    geo_data.vertices = [dynamic]Text_Vertex{}
	geo_data.indices = [dynamic]u32{}

    cs := strings.clone_to_cstring(raw_string, context.temp_allocator)

    ttf_text := ttf.CreateText(text_engine, font_sfns_mono, cs, 0)

    item := TTF_Text_Item {
        raw_string = raw_string,
        text = ttf_text,
        geo_data = geo_data,
        pos = screenpos,
        color = color,
        active = true
    }

    append(&text_items, item)

    id := next_text_id
    next_text_id += 1
    return id
}

move_text_item_center_x :: proc(item: ^TTF_Text_Item, y: f32)
{
    // TODO: need to add camera here?

    text_size : [2]i32

    ok := ttf.GetTextSize(item.text, &text_size.x, &text_size.y)
    if !ok { fmt.println("Error getting text size") }

    x := (letterbox_resolution.x - f32(text_size.x)) / 2.0

    item.pos = {x, y}
}

clear_text_items :: proc() 
{
    for &item in text_items {
        ttf.DestroyText(item.text)
        item.text = nil

        // need ? to do, or does free(..geo_data) delete it's members? 
        // delete(item.geo_data.indices) 
        // delete(item.geo_data.vertices)
        // free(item.geo_data)

    }

    clear(&text_items)

    // delete(text_items)
    // text_items = {}

    next_text_id = 0
}

// TODO: name something makes it clear this is just for rendering. move somewhere
clear_text :: proc()
{
	// TODO: why can &item or item be used?
	for &item in text_items {
		clear(&item.geo_data.vertices)
		clear(&item.geo_data.indices)
	}
}

pack_text_ttf :: proc()
{
	for &item in text_items {
		if item.active {
			pack_text_item(&item)
		}
	}
} // when are we passing in position. each frame?

// TODO: prob don't need to rebuild every frame (including clear...)?

pack_text_item :: proc(item: ^TTF_Text_Item)
{
	// // TODO: position text by size
	// text_size : [2]i32
	// ok := ttf.GetTextSize(item.text, &text_size.x, &text_size.y)
	// if !ok { fmt.println("Error getting text size") }

	atlas_draw_seq := ttf.GetGPUTextDrawData(item.text)

	for seq := atlas_draw_seq; seq != nil; seq = seq.next {

		// verts
		for i := 0; i32(i) < seq.num_vertices; i += 1 {
			xy := ([2]f32)(seq.xy[i]) + item.pos
			uv := ([2]f32)(seq.uv[i])

			vert := Text_Vertex {
				position = xy,
				color = item.color,
				uv = uv
			}
			append(&item.geo_data.vertices, vert)
			// this is a little weird: can the render data be separate?
		}

		// indices
		for i := 0; i32(i) < seq.num_indices; i+= 1 {
			append(&item.geo_data.indices, u32(seq.indices[i]))
		}
    }
}

