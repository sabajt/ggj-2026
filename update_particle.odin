package main

import "core:fmt"
import "core:math/linalg"
import "core:math/ease"

get_player_center :: proc() -> [2]f32
{
	return player.pos + GRID_PADDING / 2
}

update_particles :: proc()
{
	if create_random_particles  {
		create_random_particles = false

		grow_effect_batch_if_needed()
		re_arr := &radius_effects[len(radius_effects) - 1]

		append(re_arr, create_random_particle(.Solid))
		append(re_arr, create_random_particle(.Line))
		append(re_arr, create_random_particle(.Circles))

	}

	// update / remove

	arr_remove_indicies:= [dynamic]int{}
	defer { delete(arr_remove_indicies) }

	for arr, i in radius_effects {
		arr_length := len(arr)
		expired := 0

		for &p in arr {
			if p.expired {
				expired += 1
			} else {
				update_particle(&p)
			}
		}
		if expired == arr_length && arr_length >= MAX_RADIUS_EFFECT_BATCH {
			// TODO: check what's going on here when index becomes 0
			ordered_remove(&radius_effects, i) 
		}
	}
}

update_particle :: proc(p: ^Radius_Effect) { 

	// return early if delay 

	if p.delay_onset_t > 0 {
		p.delay_onset_t -= 1
		return
	}

	// update

	p.last_t = p.t
	raw_t_norm := f32(p.t_int) / (p.life * 60)

	switch p.ease {
		case .Quadratic_In: p.t = ease.quadratic_in(raw_t_norm)
		case .Quadratic_Out: p.t = ease.quadratic_out(raw_t_norm)
		case .Quadratic_In_Out: p.t = ease.quadratic_in_out(raw_t_norm)
		case .Cubic_In: p.t = ease.cubic_in_out(raw_t_norm)
		case .Cubic_Out: p.t = ease.cubic_out(raw_t_norm)
		case .Cubic_In_Out: p.t = ease.cubic_in_out(raw_t_norm)
		case .Quartic_In: p.t = ease.quartic_in(raw_t_norm)
		case .Quartic_Out: p.t = ease.quartic_out(raw_t_norm)
		case .Quartic_In_Out: p.t = ease.quartic_in_out(raw_t_norm)
		case .Exponential_In: p.t = ease.exponential_in(raw_t_norm)
		case .Exponential_Out: p.t = ease.exponential_out(raw_t_norm)
		case .Exponential_In_Out: p.t = ease.exponential_in_out(raw_t_norm)
		case .Linear: p.t = raw_t_norm
	}

	if raw_t_norm > 1 {
		p.expired = true

		// Early return if expired
		return
	} 

	// velocity based movement if non-zero
	if linalg.dot(p.vel, p.vel) > 0 {
		p_dir := linalg.normalize(p.vel)
		drag := [2]f32 { -p_dir.x * p.drag, -p_dir.y * p.drag }
		p.vel += (-p_dir * p.drag) 
	}

	p.last_pos = p.pos
	p.pos += p.vel

	p.t_int += 1
}

grow_effect_batch_if_needed :: proc()
{	
	if len(radius_effects) > 0 {

		batch := radius_effects[len(radius_effects) - 1] 

		if len(batch) >= MAX_RADIUS_EFFECT_BATCH {
			new_batch := [dynamic]Radius_Effect{} // TODO: look into mem allocation here 
			append(&radius_effects, new_batch)
		}
	} else {
		new_batch := [dynamic]Radius_Effect{} // TODO: look into mem allocation here 
		append(&radius_effects, new_batch)
	}
}

