#+feature dynamic-literals // TODO is this a good idea?
package game

import "core:fmt"
import rl "vendor:raylib"
import "core:math"

sfx_files := #load_directory("../assets/sfx")
music_mp3_data := #load("../assets/music.mp3")

music_volume_linear: f32 = 1.0
sfx_volume_linear: f32 = 1.0

MUSIC_BPM            :: f32(80.0)
MUSIC_BEATS_PER_BAR  :: f32(4.0)
MUSIC_SECONDS_PER_BAR :: MUSIC_BEATS_PER_BAR * 60.0 / MUSIC_BPM

_sfx_map: map[string]rl.Sound
_music: rl.Music
_music_loop_start: f32 = 0
_music_loop_end:   f32 = -1 // -1 means unset; uses raylib's native end-of-track loop

SFXSettings :: struct {pitch, volume, pitch_variation, volume_variation : f32}
default_sfx_settings:SFXSettings = {1.0, 1.0, 0, 0}

init_sfx :: proc() {
	for file in sfx_files {
		if len(file.name) < 5 || file.name[len(file.name)-4:] != ".wav" do continue
		name := file.name[:len(file.name)-4]
		wave := rl.LoadWaveFromMemory(".wav", raw_data(file.data), i32(len(file.data)))
		_sfx_map[name] = rl.LoadSoundFromWave(wave)
		rl.UnloadWave(wave)
	}

	_music = rl.LoadMusicStreamFromMemory(".mp3", raw_data(music_mp3_data), i32(len(music_mp3_data)))
	_music.looping = true
	rl.SetMusicVolume(_music, music_volume_linear)
	rl.PlayMusicStream(_music)
}

set_music_loop_points :: proc(start_bar, end_bar: f32) {
	_music_loop_start = start_bar * MUSIC_SECONDS_PER_BAR
	_music_loop_end   = end_bar   * MUSIC_SECONDS_PER_BAR
}
clear_music_loop_points :: proc() {
	set_music_loop_points(0,-1)
}

_music_is_pending_restart:bool
_music_fade_start:f32
_music_fade_end:f32
// fade out and restart at the next bar
queue_music_restart :: proc() {
	if _music_is_pending_restart do return
	curr_time := rl.GetMusicTimePlayed(_music)
	bars_played, bar_progress := math.modf(curr_time / MUSIC_SECONDS_PER_BAR)
	fmt.eprintfln("Restarting music!\n%.0f bars played and %f%% through current bar", bars_played, bar_progress*100)

	_music_fade_end = (bars_played + 1) * MUSIC_SECONDS_PER_BAR
	if bar_progress > 0.8 do _music_fade_end += MUSIC_SECONDS_PER_BAR
	_music_fade_start = curr_time
	_music_is_pending_restart = true
}

update_music :: proc() {
	rl.UpdateMusicStream(_music)

	if _music_is_pending_restart {
		curr_time := rl.GetMusicTimePlayed(_music)
		if curr_time >= _music_fade_end {
			rl.StopMusicStream(_music)
			rl.SeekMusicStream(_music, 0)
			rl.PlayMusicStream(_music)
			rl.SetMusicVolume(_music, music_volume_linear)
			_music_is_pending_restart = false
		} else {
			fade_t := (curr_time - _music_fade_start) / (_music_fade_end - _music_fade_start)
			rl.SetMusicVolume(_music, music_volume_linear * (1.0 - fade_t))
		}
	} else {
		rl.SetMusicVolume(_music, music_volume_linear)
		// loop points
		overage := rl.GetMusicTimePlayed(_music) - _music_loop_end
		if _music_loop_end >= 0 && overage > 0 && overage < MUSIC_SECONDS_PER_BAR {
			seek := _music_loop_start + overage
			fmt.eprintfln("looping music with %.2f overage", overage)
			rl.StopMusicStream(_music)
			rl.SeekMusicStream(_music, seek)
			rl.PlayMusicStream(_music)
		}
	}
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
		switch name {
		case "shoot":
			settings={pitch=1.0, volume=1.0, pitch_variation=0.05}
		case "shoot1":
			settings={pitch=1.0, volume=1.0, pitch_variation=0.1}
		case "shoot2":
			settings={pitch=1.5, volume=.5, pitch_variation=0.1, volume_variation=0.2}
		case "hit":
			settings={pitch=.5, volume=0.4, pitch_variation=0.2, volume_variation=0.2}
		case "asteroid_hit":
			settings={pitch=.8, volume=1.0, pitch_variation=0.1}
		case "projectile_hit":
			settings={pitch=1.0, volume=1.0, pitch_variation=0.15}
		case "comet_hit":
			settings={pitch=1.0, volume=0.8, pitch_variation=0.1, volume_variation=0.3}
		case "comet_break":
			settings={pitch=1.0, volume=1.0, pitch_variation=0.1, volume_variation=0.3}
		case:
			settings = default_sfx_settings
		}
	}

	volume := vary(settings.volume, settings.volume_variation)
	pitch := vary(settings.pitch, settings.pitch_variation)
	rl.SetSoundVolume(sound, volume)
	rl.SetSoundPitch(sound, pitch)
	rl.PlaySound(sound)
}
