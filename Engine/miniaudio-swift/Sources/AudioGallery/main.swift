import Foundation
import CMiniaudio

func dataCallback(_ pDevice: UnsafeMutablePointer<ma_device>?,
                 _ pOutput: UnsafeMutableRawPointer?,
                 _ pInput: UnsafeRawPointer?,
                 _ frameCount: ma_uint32) {
    guard let pDevice = pDevice else {
        return
    }

    let pDecoder = pDevice.pointee.pUserData.assumingMemoryBound(to: ma_decoder.self)
    ma_decoder_read_pcm_frames(pDecoder, pOutput, ma_uint64(frameCount), nil)
}

var decoder = ma_decoder()
let result = ma_decoder_init_file(CommandLine.unsafeArgv[1], nil, &decoder)
if result != MA_SUCCESS {
    exit(-1)
}

var deviceConfig: ma_device_config = ma_device_config_init(ma_device_type_playback)
deviceConfig.playback.format = decoder.outputFormat
deviceConfig.playback.channels = decoder.outputChannels
deviceConfig.sampleRate = decoder.outputSampleRate
deviceConfig.dataCallback = dataCallback
deviceConfig.pUserData = UnsafeMutableRawPointer(&decoder)   // Can be accessed from the device object (device.pUserData).

var device  = ma_device()

if ma_device_init(nil, &deviceConfig, &device) != MA_SUCCESS {
    print("Failed to open playback device.")
    ma_decoder_uninit(&decoder)
    exit(-1)
}

if ma_device_start(&device) != MA_SUCCESS {
    print("Failed to start playback device.")
    ma_device_uninit(&device)
    ma_decoder_uninit(&decoder)
    exit(-1)
}

print("Press enter to quit...")
getchar()