package game

import "core:fmt"
import rl "vendor:raylib"

sfx_files := #load_directory("../assets/sfx")
music_mp3_data := #load("../assets/music.mp3")

music_volume: f32 = 1.0
sfx_volume: f32 = 1.0

_sfx_map: map[string]rl.Sound
_music: rl.Music

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

	_music = rl.LoadMusicStreamFromMemory(".mp3", raw_data(music_mp3_data), i32(len(music_mp3_data)))
	_music.looping = true
	rl.SetMusicVolume(_music, music_volume)
	rl.PlayMusicStream(_music)
}

update_music :: proc() {
	rl.UpdateMusicStream(_music)
}

shutdown_sfx :: proc() {
	rl.UnloadMusicStream(_music)
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
