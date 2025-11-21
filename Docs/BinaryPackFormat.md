# Engine Internals (How it Really Works)

**You do not need to read this section for basic game development.** This is for advanced users who are debugging, optimizing, or writing plugins.

The "magic" is converting high-level data arrays (PHP/Python/Zig) into a C-compatible binary stream that the Swift engine can consume directly from memory. To support different CPU architectures (like ARM64 vs x64), the engine enforces a strict **8-byte alignment rule** for *everything*.

---

## 1. The C-Struct (The "Contract")

The engine expects data in specific packed structs. Here is the contract for the `GEOM_ADD_LINE` event. Note the `isScreenSpace` flag and the padding adjustment to ensure the struct size is divisible by 8.

```c
// Payload for adding a single geometry line.
// Total Size: 48 bytes (Divisible by 8)
typedef struct {
    int64_t id1;             // 0-7:   Primary identifier.
    int64_t id2;             // 8-15:  Secondary identifier.
    double z;                // 16-23: Z position (depth).
    uint8_t r;               // 24:    Red (0-255).
    uint8_t g;               // 25:    Green (0-255).
    uint8_t b;               // 26:    Blue (0-255).
    uint8_t a;               // 27:    Alpha (0-255).
    uint8_t isScreenSpace;   // 28:    1 = UI/Screen, 0 = World.
    uint8_t _padding[3];     // 29-31: Padding to align next float to 4 bytes.
    float x1;                // 32-35: Start X.
    float y1;                // 36-39: Start Y.
    float x2;                // 40-43: End X.
    float y2;                // 44-47: End Y.
} PackedGeomAddLineEvent;
```


* * *

## 2. The Binary Layout (Single Event)

Every individual event in a stream follows this layout.

**A. The Universal Header (16 Bytes)** Every event starts with this header.

|Offset | Type | Value | Hex (Little-Endian)|
| :--- | :--- | :--- | :--- |
| 0 | uint32 | Event Type ID | 33 00 00 00|
| 4 | uint64 | Timestamp (Always 0) | 00 00 00 00 00 00 00 00|
| 12 | x4 | Padding (Alignment) | 00 00 00 00|

**B. The Payload** Immediately follows the header. Variable length strings (like texture paths) are padded here so that the _total_ length of the event is always a multiple of 8 bytes.

* * *

## 3. The Channel Architecture (The Final Output)

When your script (PHP/Zig) finishes an update frame, it doesn't just return a random list of events. It organizes them into **Channels** (Renderer, Window, Audio, etc.).

The engine expects a **Final Output Blob** structured like a "Table of Contents" followed by the data chapters.

### A. The Structure

1.  **Channel Count Header (8 bytes):** The number of active channels, followed by 4 bytes of padding.
    
2.  **Index Table:** A list of pairs `[Channel ID, Data Size]`.
    
3.  **Data Blobs:** The raw command streams for each channel concatenated together.
    

### B. Memory View (Final Blob)

Assuming you are sending data for 2 channels: **Renderer (ID 0)** and **Window (ID 5)**.

**Part 1: The Global Header** 
| Offset | Type | Description | Value | 
| :--- | :--- | :--- | :--- |
| 0 | uint32 | **Channel Count** | `2` | 
| 4 | x4 | **Padding** (Align to 8) | `00 00 00 00` |

**Part 2: The Index Table**
| Offset | Type | Description | Value | 
| :--- | :--- | :--- | :--- |
| 8 | uint32 | **Channel ID** | `0` (Renderer) | 
| 12 | uint32 | **Size** (Bytes) | `2048` (Size of renderer stream) | 
| 16 | uint32 | **Channel ID** | `5` (Window) | 
| 20 | uint32 | **Size** (Bytes) | `64` (Size of window stream) |

**Part 3: The Data** 
| Offset | Content | Description | 
| :--- | :--- | :--- | 
| 24 | `[Renderer Stream]` | The raw sequence of events (SpriteAdd, Move, etc.) packed by `CommandPacker`. Starts with its own internal command count. | 
| 2072 | `[Window Stream]` | The raw sequence of events (WindowTitle, etc.). |

### C. Inside a Channel Stream

Crucially, **each channel's data blob** is itself a self-contained stream created by a `CommandPacker`. It starts with its own count:

1.  **Command Count (4 bytes)**
    
2.  **Padding (4 bytes)**
    
3.  **Event 1** (Header + Payload)
    
4.  **Event 2** (Header + Payload) ...
