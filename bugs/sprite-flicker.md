
In render.odin, sprites_sz on line 582 uses len(sprites) (the full map including invisible sprites) but should use len(gpu_sprites) (the packed visible subset). This causes a buffer overread on Windows, making sprites flicker. Same fix needed on line 768 for the upload guard.

sprites_sz := len(sprites) * size_of(GPU_Sprite)
sprites is a map[int]Sprite — all sprites, including invisible ones. But the actual gpu_sprites buffer only contains the visible/packed subset. So sprites_sz is too large, and the mem.copy on line 647 reads past the end of gpu_sprites into garbage memory.

Then on line 768 the upload guard also checks len(sprites) instead of len(gpu_sprites).

The reason it's Windows-specific: Mac memory likely happens to be zeroed beyond the array (Metal/OS behavior), while Windows ends up with stale/garbage data in that region, corrupting the sprite buffer.
