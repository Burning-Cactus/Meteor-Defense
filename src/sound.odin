package game

import "core:fmt"
import rl "vendor:raylib"

sfx_files := #load_directory("../assets/sfx")

sfx_volume: f32 = 1.0

_sfx_map: map[string]rl.Sound

SFXSettings :: struct {pitch, volume, pitch_variation, volume_variation : f32}
default_sfx_settings:SFXSettings = {1.0, 1.0, 0, 0}

init_sfx :: proc() {
	_sfx_map = make(map[string]rl.Sound)
	for file in sfx_files {
		if len(file.name) < 5 || file.name[len(file.name)-4:] != ".wav" do continue
		name := file.name[:len(file.name)-4]
		wave := rl.LoadWaveFromMemory(".wav", raw_data(file.data), i32(len(file.data)))
		_sfx_map[name] = rl.LoadSoundFromWave(wave)
		rl.UnloadWave(wave)
	}
}

shutdown_sfx :: proc() {
	for _, sound in _sfx_map {
		rl.UnloadSound(sound)
	}
	delete(_sfx_map)
}

play_sfx :: proc(name: string, settings:SFXSettings={}) {
	sound, ok := _sfx_map[name]
	if !ok {
		fmt.eprintln("play_sfx: sound not found:", name)
		return
	}

	settings:=settings
	if settings == {} {
		settings = default_sfx_settings
	}

	volume := vary(settings.volume, settings.volume_variation)
	pitch := vary(settings.pitch, settings.pitch_variation)
	rl.SetSoundVolume(sound, volume)
	rl.SetSoundPitch(sound, pitch)
	rl.PlaySound(sound)
}
