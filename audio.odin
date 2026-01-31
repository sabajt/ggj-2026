package main

import "core:strings"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import sdl "vendor:sdl3"

audio_device: sdl.AudioDeviceID = 0
sounds: [dynamic]Sound

Sound :: struct {
    wav_data: [^]u8,
    wav_data_len: u32,
    stream: ^sdl.AudioStream
}

play_sound :: proc(i: int)
{
    sdl.PutAudioStreamData(sounds[i].stream, sounds[i].wav_data, i32(sounds[i].wav_data_len))
}

init_audio :: proc()
{
    audio_device = sdl.OpenAudioDevice(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)
    if audio_device == 0 {
        fmt.println("failed to open audio device: ", sdl.GetError())
    }

    sound_names := []string {
        "click_0",      // 0
        "zap_1",        // 1
        "zap_2",        // 2
        "drop",         // 3
        "pause",        // 4
        "bigboom_1",    // 5
        "bigboom_2",    // 6
        "bigboom_3",    // 7
        "warp_1",       // 8
        "bigboom_4",    // 9
        "aim",          // 10
        "throw"         // 11
    }
    for s in sound_names {
        name := fmt.tprintf("sounds/%v.wav", s)
        sound: Sound 
        init_sound(name, &sound)
        append(&sounds, sound)
    }
}

init_sound :: proc(file_name: string, sound: ^Sound) -> bool
{
    spec: sdl.AudioSpec
    wave_path := strings.clone_to_cstring(file_name, context.temp_allocator)

    ok := sdl.LoadWAV(wave_path, &spec, &sound.wav_data, &sound.wav_data_len)
    if !ok {
        fmt.println("failed to load audio: ", sdl.GetError())
        return false
    }

    sound.stream = sdl.CreateAudioStream(&spec, nil)
    if sound.stream == nil {
        fmt.println("failed to create audio stream: ", sdl.GetError())
        return false
    }
    if !sdl.BindAudioStream(audio_device, sound.stream) {
        fmt.println("failed to bind stream to device: ", sdl.GetError())
        return false
    }
    return true
}

cleanup_sound :: proc()
{
    sdl.CloseAudioDevice(audio_device)
    for s in sounds {
        if s.stream != nil {
            sdl.DestroyAudioStream(s.stream)
        }
        sdl.free(s.wav_data)
    }
    delete(sounds)
}

