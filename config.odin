package main

config := Config {
    resolution = 3 * INTERNAL_RES,
    font_size = 32
}

// config := Config {
//     resolution = 2 * INTERNAL_RES,
//     font_size = 24
// }

Config :: struct {
    resolution: [2]f32,
    font_size: f32,
}

