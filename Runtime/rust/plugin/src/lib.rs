// --- Imports ---
// This imports all the generated structs and helpers
mod events;
use events::*;

// --- ADDED Imports for Channel Packing ---
use events::{ChannelInput, ChannelPacker, Channels};
// ---

// use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt}; // <-- REMOVED (now handled in events.rs)
use libc::{c_double, c_int, c_ulonglong, c_void, free, malloc, memcpy};
use once_cell::sync::Lazy;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use std::fs::{self, File};
use std::io::{/*BufReader,*/ BufWriter, /*Read,*/ Write}; // <-- CLEANED UP
use std::mem;
use std::ptr;
use std::slice;
use std::sync::Mutex;

// --- Global Constants ---
const FPS_SAMPLE_SIZE: usize = 60;
const MAX_SPRITES: usize = 64000;
const TEXTURE_PATH: &str = "assets/wabbit_alpha.png";
const SAVE_FILE_PATH: &str = "save.dat";

// --- Sprite Struct ---
// Must be #[repr(C)] to be safely serialized/deserialized from a file.
#[repr(C)]
#[derive(Debug, Copy, Clone)]
struct Sprite {
    id1: i64,
    id2: i64,
    pos: [f64; 2],
    speed: [f64; 2],
    color: [u8; 4],
}

impl Sprite {
    /// Updated to use dynamic window size and add ejection logic
    pub fn update(
        &mut self,
        dt: f64,
        window_width: i32,
        window_height: i32,
        packer: &mut CommandPacker, // <-- MODIFIED: This is now packer_render
    ) -> std::io::Result<()> {
        // 1. Apply physics
        self.pos[0] += self.speed[0] * dt;
        self.pos[1] += self.speed[1] * dt;

        let mut speed_changed = false;

        // 2. Define constants from world state
        let boundary_left: f64 = 12.0;
        let boundary_right: f64 = window_width as f64 - 12.0;
        let boundary_top: f64 = 16.0;
        let boundary_bottom: f64 = window_height as f64 - 16.0;

        const HOTSPOT_OFFSET_X: f64 = 16.0;
        const HOTSPOT_OFFSET_Y: f64 = 16.0;

        let hotspot_x = self.pos[0] + HOTSPOT_OFFSET_X;
        let hotspot_y = self.pos[1] + HOTSPOT_OFFSET_Y;

        // 3. Boundary collision logic with ejection
        if hotspot_x > boundary_right {
            self.speed[0] *= -1.0;
            self.pos[0] = boundary_right - HOTSPOT_OFFSET_X; // Eject
            speed_changed = true;
        } else if hotspot_x < boundary_left {
            self.speed[0] *= -1.0;
            self.pos[0] = boundary_left - HOTSPOT_OFFSET_X; // Eject
            speed_changed = true;
        }

        if hotspot_y > boundary_bottom {
            self.speed[1] *= -1.0;
            self.pos[1] = boundary_bottom - HOTSPOT_OFFSET_Y; // Eject
            speed_changed = true;
        } else if hotspot_y < boundary_top {
            self.speed[1] *= -1.0;
            self.pos[1] = boundary_top - HOTSPOT_OFFSET_Y; // Eject
            speed_changed = true;
        }

        // 4. Pack move event
        packer.pack(
            Events::spriteMove,
            &PackedSpriteMoveEvent {
                id1: self.id1,
                id2: self.id2,
                position_x: self.pos[0],
                position_y: self.pos[1],
                position_z: 0.0,
            },
        )?;

        // 5. Pack speed event *only if it changed*
        if speed_changed {
            packer.pack(
                Events::spriteSpeed,
                &PackedSpriteSpeedEvent {
                    id1: self.id1,
                    id2: self.id2,
                    speed_x: self.speed[0],
                    speed_y: self.speed[1],
                },
            )?;
        }

        Ok(())
    }
}

// --- Global State ---
struct World {
    sprites: Vec<Sprite>,
    sprites_count: u64,
    mouse_x: f32,
    mouse_y: f32,
    smoothed_fps: f64,
    fps_samples: Vec<f64>,
    prng: StdRng,
    window_width: i32,
    window_height: i32,
}

impl World {
    fn new() -> Self {
        // Seed the PRNG
        let seed = rand::thread_rng().gen();
        Self {
            sprites: Vec::with_capacity(MAX_SPRITES),
            sprites_count: 0,
            mouse_x: 0.0,
            mouse_y: 0.0,
            smoothed_fps: 0.0,
            fps_samples: Vec::with_capacity(FPS_SAMPLE_SIZE),
            prng: StdRng::from_seed(seed),
            window_width: 800,
            window_height: 450,
        }
    }
}

// Use once_cell::Lazy to safely initialize the global state.
// This also handles the `is_initialized` flag automatically.
static WORLD: Lazy<Mutex<World>> = Lazy::new(|| {
    println!("--- Initializing Rust World State ---");
    // You can add your event size print loop here if needed
    Mutex::new(World::new())
});

/// Helper to ensure the global state is initialized.
fn init_world() {
    // let _ = WORLD.lock().unwrap(); // This lazy-initializes the world on first call
    let _unused = WORLD.lock().unwrap();
}

/// Helper function to replicate Zig's `event_payload_sizes` map.
/// This is needed for the robust event unpacker loop.
fn get_payload_size(event: Events) -> Option<u32> {
    Some(match event {
        Events::spriteAdd => mem::size_of::<PackedSpriteAddEvent>() as u32,
        Events::spriteRemove => mem::size_of::<PackedSpriteRemoveEvent>() as u32,
        Events::spriteMove => mem::size_of::<PackedSpriteMoveEvent>() as u32,
        Events::spriteScale => mem::size_of::<PackedSpriteScaleEvent>() as u32,
        Events::spriteResize => mem::size_of::<PackedSpriteResizeEvent>() as u32,
        Events::spriteRotate => mem::size_of::<PackedSpriteRotateEvent>() as u32,
        Events::spriteColor => mem::size_of::<PackedSpriteColorEvent>() as u32,
        Events::spriteSpeed => mem::size_of::<PackedSpriteSpeedEvent>() as u32,
        Events::spriteTextureLoad => mem::size_of::<PackedTextureLoadHeaderEvent>() as u32,
        Events::spriteTextureSet => mem::size_of::<PackedSpriteTextureSetEvent>() as u32,
        Events::spriteSetSourceRect => mem::size_of::<PackedSpriteSetSourceRectEvent>() as u32,
        Events::geomAddPoint => mem::size_of::<PackedGeomAddPointEvent>() as u32,
        Events::geomAddLine => mem::size_of::<PackedGeomAddLineEvent>() as u32,
        Events::geomAddRect => mem::size_of::<PackedGeomAddRectEvent>() as u32,
        Events::geomAddFillRect => mem::size_of::<PackedGeomAddRectEvent>() as u32,
        Events::geomAddPacked => mem::size_of::<PackedGeomAddPackedHeaderEvent>() as u32,
        Events::geomRemove => mem::size_of::<PackedGeomRemoveEvent>() as u32,
        Events::geomSetColor => mem::size_of::<PackedGeomSetColorEvent>() as u32,
        Events::inputKeyup => mem::size_of::<PackedKeyEvent>() as u32,
        Events::inputKeydown => mem::size_of::<PackedKeyEvent>() as u32,
        Events::inputMouseup => mem::size_of::<PackedMouseButtonEvent>() as u32,
        Events::inputMousedown => mem::size_of::<PackedMouseButtonEvent>() as u32,
        Events::inputMousemotion => mem::size_of::<PackedMouseMotionEvent>() as u32,
        Events::windowTitle => mem::size_of::<PackedWindowTitleEvent>() as u32,
        Events::windowResize => mem::size_of::<PackedWindowResizeEvent>() as u32,
        Events::windowFlags => mem::size_of::<PackedWindowFlagsEvent>() as u32,
        Events::textAdd => mem::size_of::<PackedTextAddEvent>() as u32,
        Events::textSetString => mem::size_of::<PackedTextSetStringEvent>() as u32,
        Events::audioLoad => mem::size_of::<PackedAudioLoadEvent>() as u32,
        Events::audioLoaded => mem::size_of::<PackedAudioLoadedEvent>() as u32,
        Events::audioPlay => mem::size_of::<PackedAudioPlayEvent>() as u32,
        Events::audioPause => mem::size_of::<PackedAudioPauseEvent>() as u32,
        Events::audioStop => mem::size_of::<PackedAudioStopEvent>() as u32,
        Events::audioUnload => mem::size_of::<PackedAudioUnloadEvent>() as u32,
        Events::audioSetVolume => mem::size_of::<PackedAudioSetVolumeEvent>() as u32,
        Events::audioStopAll => 0,
        Events::audioSetMasterVolume => mem::size_of::<PackedAudioSetMasterVolumeEvent>() as u32,
        Events::physicsAddBody => mem::size_of::<PackedPhysicsAddBodyEvent>() as u32,
        Events::physicsRemoveBody => mem::size_of::<PackedPhysicsRemoveBodyEvent>() as u32,
        Events::physicsApplyForce => mem::size_of::<PackedPhysicsApplyForceEvent>() as u32,
        Events::physicsApplyImpulse => mem::size_of::<PackedPhysicsApplyImpulseEvent>() as u32,
        Events::physicsSetVelocity => mem::size_of::<PackedPhysicsSetVelocityEvent>() as u32,
        Events::physicsSetPosition => mem::size_of::<PackedPhysicsSetPositionEvent>() as u32,
        Events::physicsSetRotation => mem::size_of::<PackedPhysicsSetRotationEvent>() as u32,
        Events::physicsCollisionBegin => mem::size_of::<PackedPhysicsCollisionEvent>() as u32,
        Events::physicsCollisionSeparate => mem::size_of::<PackedPhysicsCollisionEvent>() as u32,
        Events::physicsSyncTransform => mem::size_of::<PackedPhysicsSyncTransformEvent>() as u32,
        Events::physicsSetDebugMode => mem::size_of::<PackedPhysicsSetDebugModeEvent>() as u32,
        Events::plugin => mem::size_of::<PackedPluginOnEvent>() as u32,
        Events::pluginLoad => mem::size_of::<PackedPluginLoadHeaderEvent>() as u32,
        Events::pluginUnload => mem::size_of::<PackedPluginUnloadEvent>() as u32,
        Events::pluginSet => mem::size_of::<PackedPluginSetEvent>() as u32,
        Events::pluginEventStacking => mem::size_of::<PackedPluginEventStackingEvent>() as u32,
        Events::pluginSubscribeEvent => mem::size_of::<PackedPluginSubscribeEvent>() as u32,
        Events::pluginUnsubscribeEvent => mem::size_of::<PackedPluginUnsubscribeEvent>() as u32,
        Events::cameraSetPosition => mem::size_of::<PackedCameraSetPositionEvent>() as u32,
        Events::cameraMove => mem::size_of::<PackedCameraMoveEvent>() as u32,
        Events::cameraSetZoom => mem::size_of::<PackedCameraSetZoomEvent>() as u32,
        Events::cameraSetRotation => mem::size_of::<PackedCameraSetRotationEvent>() as u32,
        Events::cameraFollowEntity => mem::size_of::<PackedCameraFollowEntityEvent>() as u32,
        Events::cameraStopFollowing => 0,
        Events::scriptSubscribe => mem::size_of::<PackedScriptSubscribeEvent>() as u32,
        Events::scriptUnsubscribe => mem::size_of::<PackedScriptUnsubscribeEvent>() as u32,
    })
}

/// Helper to allocate and copy a byte buffer to be sent to C land.
unsafe fn return_buffer(buffer: Vec<u8>, out_length: *mut c_int) -> *mut c_void {
    let len = buffer.len();
    let swift_ptr = malloc(len);
    if swift_ptr.is_null() {
        *out_length = 0;
        return ptr::null_mut();
    }
    memcpy(swift_ptr, buffer.as_ptr() as *const c_void, len);
    *out_length = len as c_int;
    swift_ptr
}

// --- Exported C-ABI Functions ---

#[no_mangle]
pub extern "C" fn Phrost_Wake(out_length: *mut c_int) -> *mut c_void {
    // 1. Initialize world
    init_world();
    let mut world = WORLD.lock().unwrap();
    // --- MODIFIED: Use packer_render ---
    let mut packer_render = CommandPacker::new();

    // 3. Try to load the save file
    let file_bytes = match fs::read(SAVE_FILE_PATH) {
        Ok(bytes) => bytes,
        Err(e) => {
            if e.kind() == std::io::ErrorKind::NotFound {
                println!("Phrost_Wake: No save.dat found. Starting new world.");
            } else {
                eprintln!("Phrost_Wake: Error reading save.dat: {}", e);
            }
            unsafe { *out_length = 0 };
            return ptr::null_mut();
        }
    };

    // 4. Deserialize
    if file_bytes.len() % mem::size_of::<Sprite>() != 0 {
        eprintln!(
            "Phrost_Wake: save.dat has invalid size ({} bytes). Ignoring.",
            file_bytes.len()
        );
        unsafe { *out_length = 0 };
        return ptr::null_mut();
    }

    let loaded_sprites: &[Sprite] = unsafe {
        slice::from_raw_parts(
            file_bytes.as_ptr() as *const Sprite,
            file_bytes.len() / mem::size_of::<Sprite>(),
        )
    };
    println!(
        "Phrost_Wake: Loading {} sprites from save.dat...",
        loaded_sprites.len()
    );

    // 5. Populate world and re-emit commands
    for &sprite in loaded_sprites {
        if world.sprites.len() >= MAX_SPRITES {
            eprintln!("Phrost_Wake: World full while loading save.dat!");
            break;
        }

        world.sprites.push(sprite);
        world.sprites_count += 1;

        // Re-emit spriteAdd
        let _ = packer_render.pack(
            Events::spriteAdd,
            &PackedSpriteAddEvent {
                id1: sprite.id1,
                id2: sprite.id2,
                position_x: sprite.pos[0],
                position_y: sprite.pos[1],
                position_z: 0.0,
                scale_x: 1.0,
                scale_y: 1.0,
                scale_z: 1.0,
                size_w: 32.0,
                size_h: 32.0,
                rotation_x: 0.0,
                rotation_y: 0.0,
                rotation_z: 0.0,
                r: sprite.color[0],
                g: sprite.color[1],
                b: sprite.color[2],
                a: sprite.color[3],
                _padding: 0,
                speed_x: sprite.speed[0],
                speed_y: sprite.speed[1],
            },
        );

        // Re-emit textureLoad
        let _ =
            packer_render.pack_sprite_texture_load(sprite.id1, sprite.id2, TEXTURE_PATH.as_bytes());
    }

    println!(
        "Phrost_Wake: Finished loading. Re-emitting {} commands.",
        packer_render.command_count()
    );

    // 6. Finalize and return
    let render_buffer = packer_render.finalize();

    // Define channel inputs
    let channel_inputs = [ChannelInput {
        id: Channels::renderer,
        data: &render_buffer,
    }];

    // Pack channels into the final buffer
    let final_buffer = match ChannelPacker::finalize(&channel_inputs) {
        Ok(buf) => buf,
        Err(e) => {
            eprintln!("Phrost_Wake: Failed to finalize channel packer: {}", e);
            unsafe { *out_length = 0 };
            return ptr::null_mut();
        }
    };

    unsafe { return_buffer(final_buffer, out_length) }
}

#[no_mangle]
pub extern "C" fn Phrost_Update(
    _timestamp: c_ulonglong,
    dt: c_double,
    events_blob: *const c_void,
    events_length: c_int,
    out_length: *mut c_int,
) -> *mut c_void {
    // --- Initialization ---
    init_world();
    // --- Create separate packers ---
    let mut packer_render = CommandPacker::new();
    let mut packer_window = CommandPacker::new();
    // ---
    let mut world = WORLD.lock().unwrap();

    // --- FPS Calculation ---
    if dt > 0.0 {
        if world.fps_samples.len() == FPS_SAMPLE_SIZE {
            world.fps_samples.remove(0);
        }
        world.fps_samples.push(dt);

        let sum: f64 = world.fps_samples.iter().sum();
        if !world.fps_samples.is_empty() {
            let average_dt = sum / world.fps_samples.len() as f64;
            if average_dt > 0.0 {
                world.smoothed_fps = 1.0 / average_dt;
            }
        }
    }

    // --- Event Unpacking ---
    let mut add_sprites = false;
    if !events_blob.is_null() && events_length > 0 {
        let blob_slice =
            unsafe { slice::from_raw_parts(events_blob as *const u8, events_length as usize) };
        let mut unpacker = EventUnpacker::new(blob_slice);

        // Read Count (handles u32 + 4 byte padding)
        let _event_count = unpacker.read_count().unwrap_or(0);
        let blob_len = blob_slice.len();
        const EVENT_HEADER_SIZE: u64 = 16; // 4 Type + 8 Time + 4 Pad

        while unpacker.position() + EVENT_HEADER_SIZE <= blob_len as u64 {
            // Read Header (handles padding)
            let (event_type, _timestamp) = match unpacker.read_event_header() {
                Ok(header) => header,
                Err(_) => break, // Couldn't read header
            };

            let payload_size = match get_payload_size(event_type) {
                Some(size) => size,
                None => {
                    eprintln!(
                        "Unknown payload size for event: {:?}. Stopping.",
                        event_type
                    );
                    break;
                }
            };

            if unpacker.position() + payload_size as u64 > blob_len as u64 {
                break;
            }

            // Process Payload
            match event_type {
                // Variable length events - strings + padding
                Events::spriteTextureLoad => {
                    if let Ok(header) = unpacker.read_payload::<PackedTextureLoadHeaderEvent>() {
                        let _ = unpacker.skip_string_aligned(header.filename_length);
                    } else {
                        break;
                    }
                }
                Events::textSetString => {
                    if let Ok(header) = unpacker.read_payload::<PackedTextSetStringEvent>() {
                        let _ = unpacker.skip_string_aligned(header.text_length);
                    } else {
                        break;
                    }
                }
                Events::textAdd => {
                    if let Ok(header) = unpacker.read_payload::<PackedTextAddEvent>() {
                        let _ = unpacker.skip_string_aligned(header.font_path_length);
                        let _ = unpacker.skip_string_aligned(header.text_length);
                    } else {
                        break;
                    }
                }
                Events::pluginLoad => {
                    if let Ok(header) = unpacker.read_payload::<PackedPluginLoadHeaderEvent>() {
                        let _ = unpacker.skip_string_aligned(header.path_length);
                    } else {
                        break;
                    }
                }
                Events::audioLoad => {
                    // Special case: struct 4 bytes, skip 4 padding, then read string
                    if let Ok(header) = unpacker.read_payload::<PackedAudioLoadEvent>() {
                        let _ = unpacker.skip(4);
                        let _ = unpacker.skip_string_aligned(header.path_length);
                    } else {
                        break;
                    }
                }

                // Fixed length events
                Events::windowTitle => {
                    let _ = unpacker.skip(payload_size);
                }
                Events::inputMousemotion => {
                    if let Ok(event) = unpacker.read_payload::<PackedMouseMotionEvent>() {
                        world.mouse_x = event.x;
                        world.mouse_y = event.y;
                    } else {
                        break;
                    }
                }
                Events::inputMousedown => {
                    if let Ok(_) = unpacker.read_payload::<PackedMouseButtonEvent>() {
                        add_sprites = true;
                    } else {
                        break;
                    }
                }
                Events::inputKeydown => {
                    if let Ok(event) = unpacker.read_payload::<PackedKeyEvent>() {
                        if event.keycode == 97 {
                            add_sprites = true;
                        }
                    } else {
                        break;
                    }
                }
                Events::windowResize => {
                    if let Ok(event) = unpacker.read_payload::<PackedWindowResizeEvent>() {
                        world.window_width = event.w;
                        world.window_height = event.h;
                    } else {
                        break;
                    }
                }
                _ => {
                    let _ = unpacker.skip(payload_size);
                }
            }

            // ALIGNMENT: Ensure next header starts at 8-byte boundary
            let _ = unpacker.align_to(8);
        }
    }
    // --- END Event Unpacking ---

    // --- Window Title Update ---
    let title = format!(
        "Bunny Benchmark | Sprites: {} | FPS: {:.0}",
        world.sprites_count, world.smoothed_fps
    );
    let mut title_event = PackedWindowTitleEvent { title: [0; 256] };
    let title_bytes = title.as_bytes();
    let len_to_copy = title_bytes.len().min(255); // Leave room for null
    title_event.title[..len_to_copy].copy_from_slice(&title_bytes[..len_to_copy]);
    let _ = packer_window.pack(Events::windowTitle, &title_event);

    // --- Main Game Logic ---
    let (win_w, win_h) = (world.window_width, world.window_height);
    for sprite in world.sprites.iter_mut() {
        let _ = sprite.update(dt, win_w, win_h, &mut packer_render);
    }

    // --- Add Sprites Loop ---
    if add_sprites && world.sprites_count < MAX_SPRITES as u64 {
        for _ in 0..1000 {
            if world.sprites_count >= MAX_SPRITES as u64 {
                break;
            }
            let id1 = world.sprites_count as i64;
            let id2: i64 = 0;

            let r = world.prng.gen_range(50..=240);
            let g = world.prng.gen_range(80..=240);
            let b = world.prng.gen_range(100..=240);

            let sprite = Sprite {
                id1,
                id2,
                pos: [world.mouse_x as f64, world.mouse_y as f64],
                speed: [
                    world.prng.gen_range(-250.0..=500.0),
                    world.prng.gen_range(-250.0..=500.0),
                ],
                color: [r, g, b, 255],
            };

            world.sprites.push(sprite);

            let _ = packer_render.pack(
                Events::spriteAdd,
                &PackedSpriteAddEvent {
                    id1,
                    id2,
                    position_x: sprite.pos[0],
                    position_y: sprite.pos[1],
                    position_z: 0.0,
                    scale_x: 1.0,
                    scale_y: 1.0,
                    scale_z: 1.0,
                    size_w: 32.0,
                    size_h: 32.0,
                    rotation_x: 0.0,
                    rotation_y: 0.0,
                    rotation_z: 0.0,
                    r,
                    g,
                    b,
                    a: 255,
                    _padding: 0,
                    speed_x: sprite.speed[0],
                    speed_y: sprite.speed[1],
                },
            );

            let _ = packer_render.pack_sprite_texture_load(id1, id2, TEXTURE_PATH.as_bytes());

            world.sprites_count += 1;
        }
    }

    // --- Finalize & Return ---
    let render_buffer = packer_render.finalize();
    let window_buffer = packer_window.finalize();

    let channel_inputs = [
        ChannelInput {
            id: Channels::renderer,
            data: &render_buffer,
        },
        ChannelInput {
            id: Channels::window,
            data: &window_buffer,
        },
    ];

    let final_buffer = match ChannelPacker::finalize(&channel_inputs) {
        Ok(buf) => buf,
        Err(e) => {
            eprintln!("Phrost_Update: Failed to finalize channel packer: {}", e);
            unsafe { *out_length = 0 };
            return ptr::null_mut();
        }
    };

    unsafe { return_buffer(final_buffer, out_length) }
}

#[no_mangle]
pub extern "C" fn Phrost_Free(data_ptr: *mut c_void) {
    if !data_ptr.is_null() {
        unsafe {
            free(data_ptr);
        }
    }
}

#[no_mangle]
pub extern "C" fn Phrost_Sleep() {
    let world = match WORLD.try_lock() {
        Ok(guard) => guard,
        Err(_) => {
            eprintln!("Phrost_Sleep: Could not acquire world lock. Save skipped.");
            return;
        }
    };

    if world.sprites.is_empty() {
        // Delete the save file if it exists
        if fs::remove_file(SAVE_FILE_PATH).is_ok() {
            println!("Phrost_Sleep: No sprites, deleted save.dat.");
        }
    } else {
        println!(
            "Phrost_Sleep: Saving {} sprites to save.dat...",
            world.sprites.len()
        );

        let file = match File::create(SAVE_FILE_PATH) {
            Ok(f) => f,
            Err(e) => {
                eprintln!("Phrost_Sleep: FAILED to create save.dat: {}", e);
                return;
            }
        };
        let mut writer = BufWriter::new(file);

        // Convert Vec<Sprite> to &[u8]
        let sprite_bytes: &[u8] = unsafe {
            std::slice::from_raw_parts(
                world.sprites.as_ptr() as *const u8,
                world.sprites.len() * mem::size_of::<Sprite>(),
            )
        };

        if let Err(e) = writer.write_all(sprite_bytes) {
            eprintln!("Phrost_Sleep: FAILED to write save.dat: {}", e);
        }
    }
}
