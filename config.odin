package main

config := Config {
    resolution = {700, 700},
    font_size = 18, 
    fullscreen = true,
    title = "Mask Mage"
}

// config := Config {
//     resolution = {3 * INTERNAL_RES.x, 2.5 * INTERNAL_RES.y},
//     font_size = 18 // 32 monogram
// }

// config := Config {
//     resolution = 3 * INTERNAL_RES,
//     font_size = 18 // 32 monogram
// }

// config := Config {
//     resolution = 2 * INTERNAL_RES,
//     font_size = 15 // 20 monogram
// }

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

