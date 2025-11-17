// Engine+Audio.swift
import Foundation
import SwiftSDL
import CMiniaudio // <-- Use CMiniaudio, not SwiftSDL_mixer

extension PhrostEngine {

    /**
     * Loads an audio file, decodes it, and stores it in cache.
     * This uses `ma_sound_init_from_file` which pre-loads the sound.
     */
    internal func loadAudio(path: String) -> (audioId: UInt64, success: Bool) {
        // 1. Check if we've already loaded this file path
        if let existingID = loadedAudioFiles[path] {
            // Verify it's still in the cache (it should be)
            if audioCache[existingID] != nil {
                return (existingID, true)
            } else {
                print(
                    "Audio Cache Error: ID found for '\(path)' but sound pointer is missing. Reloading."
                )
                loadedAudioFiles.removeValue(forKey: path)
            }
        }

        // 2. Not in cache, load it.
        // We must allocate a stable pointer for the ma_sound struct
        let soundPtr = UnsafeMutablePointer<ma_sound>.allocate(capacity: 1)
        soundPtr.initialize(to: ma_sound())

        // 3. Initialize the sound.
        // MA_SOUND_FLAG_DECODE = pre-decode and cache in memory.
        // MA_SOUND_FLAG_NO_SPATIALIZATION = play as simple stereo/mono.
        let flags = UInt32(MA_SOUND_FLAG_DECODE.rawValue | MA_SOUND_FLAG_NO_SPATIALIZATION.rawValue)
        let result = ma_sound_init_from_file(
            &self.maEngine,
            path,
            flags,
            nil,
            nil,
            soundPtr
        )

        if result != MA_SUCCESS {
            print("ma_sound_init_from_file Error for '\(path)': \(result)")
            soundPtr.deallocate() // Clean up allocation on failure
            return (0, false)
        }

        // 4. Store it in our caches
        let newID = nextAudioID
        nextAudioID &+= 1

        audioCache[newID] = soundPtr
        loadedAudioFiles[path] = newID

        print("Loaded audio '\(path)' with ID \(newID) into cache.")
        return (newID, true)
    }

    /**
     * Plays a pre-loaded sound from the cache.
     */
    internal func handleAudioPlayCommand(event: PackedAudioPlayEvent) {
        guard let soundPtr = audioCache[event.audioId] else {
            print("Audio Play Error: called with invalid or unloaded audio ID \(event.audioId).")
            return
        }

        // Reset the sound to the beginning in case it's already playing
        ma_sound_seek_to_pcm_frame(soundPtr, 0)

        // Play the sound
        let result = ma_sound_start(soundPtr)
        if result != MA_SUCCESS {
            print("ma_engine_play_sound Error: \(result)")
        } else {
            // For debugging: get the path from the ID
            var filename = "[path not found]"
            for (path, id) in loadedAudioFiles {
                if id == event.audioId {
                    filename = path
                    break
                }
            }
            print("Playing Audio '\(filename)' (ID: \(event.audioId))")
        }
    }

    /**
     * Creates a Data blob for an audioLoaded event.
     * (This function remains unchanged from your original).
     */
    internal func makeAudioLoadedEvent(audioId: UInt64) -> Data {
        var eventData = Data()
        let loadedEvent = PackedAudioLoadedEvent(audioId: audioId)
        eventData.append(value: Events.audioLoaded.rawValue)
        eventData.append(value: SDL_GetTicks())
        eventData.append(value: loadedEvent)
        return eventData
    }

    /**
     * Pauses a specific sound at its current position.
     * Calling `ma_sound_start` (via .audioPlay) will resume it.
     */
    internal func handleAudioPauseCommand(event: PackedAudioPauseEvent) {
        guard let soundPtr = audioCache[event.audioId] else {
            print("Audio Pause Error: invalid audio ID \(event.audioId).")
            return
        }
        ma_sound_stop(soundPtr)
        print("Paused Audio ID \(event.audioId)")
    }

    /**
        * Stops a specific sound and rewinds it to the beginning.
        */
    internal func handleAudioStopCommand(event: PackedAudioStopEvent) {
        guard let soundPtr = audioCache[event.audioId] else {
            print("Audio Stop Error: invalid audio ID \(event.audioId).")
            return
        }
        ma_sound_stop(soundPtr)
        ma_sound_seek_to_pcm_frame(soundPtr, 0)
        print("Stopped and Rewound Audio ID \(event.audioId)")
    }

    /**
        * Sets the volume for a single sound.
        */
    internal func handleAudioSetVolumeCommand(event: PackedAudioSetVolumeEvent) {
        guard let soundPtr = audioCache[event.audioId] else {
            print("Audio SetVolume Error: invalid audio ID \(event.audioId).")
            return
        }
        ma_sound_set_volume(soundPtr, event.volume)
        print("Set Audio ID \(event.audioId) volume to \(event.volume)")
    }

    /**
        * Uninitializes and unloads a specific sound, freeing its memory.
        * Also removes it from all engine caches.
        */
    internal func unloadAudio(audioId: UInt64) {
        // 1. Find the path associated with this ID
        guard let path = audioIdToPath[audioId] else {
            print("Audio Unload Error: No path found for ID \(audioId). Already unloaded?")
            return
        }

        // 2. Find the sound pointer
        guard let soundPtr = audioCache[audioId] else {
            print("Audio Unload Error: No sound pointer found for ID \(audioId). Already unloaded?")
            return
        }

        // 3. Uninitialize and deallocate the sound
        ma_sound_uninit(soundPtr)
        soundPtr.deallocate()

        // 4. Remove from all caches
        let removedPtr = audioCache.removeValue(forKey: audioId)
        let removedPath = audioIdToPath.removeValue(forKey: audioId)
        let removedFile = loadedAudioFiles.removeValue(forKey: path)

        if removedPtr != nil && removedPath != nil && removedFile != nil {
            print("Successfully unloaded audio '\(path)' (ID: \(audioId)).")
        } else {
            print("Audio Unload Warning: Cleaned up ID \(audioId), but caches were inconsistent.")
        }
    }
}
