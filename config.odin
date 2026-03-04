package main

config := Config {
    resolution = 3 * INTERNAL_RES,
    font_size = 18, 
    fullscreen = false,
    title = "Mask Mage"
}

// config := Config {
//     resolution = INTERNAL_RES,
//     font_size = 9 // 14 monogram
// }

Config :: struct {
    resolution: [2]f32,
    font_size: f32,
    fullscreen: bool,
    title: string
}

