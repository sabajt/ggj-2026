package main

import "core:fmt"
import "core:os"
import "core:encoding/json"

load_json_obj :: proc(file: string, obj: ^$T)
{
	json_data, ok := os.read_entire_file(file, context.temp_allocator)
	assert(ok, fmt.tprint("Failed to read file ", file))

	error := json.unmarshal(json_data, obj)
	assert(error == nil, fmt.tprint("Failed to unmarshal json ", file))
}
