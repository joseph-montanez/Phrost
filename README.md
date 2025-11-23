Phrost: The Language-Agnostic 2D Game Engine
============================================

Phrost is a high-performance, event-driven 2D game engine. Its core design is **language-agnostic**, allowing it to be controlled by various programming languages without requiring extra libraries.

This unique architecture lets you choose the best integration model for your project, balancing raw performance with rapid development features like hot-reloading.

* * *

Downloads (Latest Auto-Build)
-----------------------------

| Platform | Status | Download |
| :--- | :---: | :---: |
| **Windows + PHP 8.4.10 (Arm64)** | [![Phrost Engine (Arm64)](https://github.com/joseph-montanez/Phrost/actions/workflows/windows-arm-build.yml/badge.svg)](https://github.com/joseph-montanez/Phrost/actions/workflows/windows-arm-build.yml) | [**Download Latest**](https://nightly.link/joseph-montanez/Phrost/workflows/windows-arm-build.yml/master/Phrost-Windows-Arm64.zip) |
| **Windows + PHP 8.5.0 (x64)** | [![Phrost Engine (x64)](https://github.com/joseph-montanez/Phrost/actions/workflows/windows-x64-build.yml/badge.svg)](https://github.com/joseph-montanez/Phrost/actions/workflows/windows-x64-build.yml) | [**Download Latest**](https://nightly.link/joseph-montanez/Phrost/workflows/windows-x64-build.yml/master/Phrost-Windows-x64.zip) |

Current Language Support
---------------------------

This table shows which languages can use which integration mode.

| Language | Wrapper API | Embedded | Client (Hot-Reload) | Can Write Plugins | Bundle Distribution |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **PHP** | ✅ | ✅ | ✅ | | ✅ |
| **Python** | (WIP) | | ✅ | | |
| **JavaScript** | (WIP) | | ✅ | | |
| **Lua** | (WIP) | | ✅ | | |
| **Rust** | | | | ✅ | |
| **Zig** | | | | ✅ | |
| **C** | | | | ✅ | |


* * *

Architecture & Integration Modes
-----------------------------------

You can integrate Phrost with your language in several ways:

*   **Embedded Mode** The engine is compiled directly as an extension into your language's runtime (e.g., a PHP extension). This runs everything in a single process and offers the absolute best performance as you can enable JIT (a ~5% boost over Client mode). This mode does not work with hot-reloading.

*   **Client/Server Mode** Phrost runs as a separate server process, and your game logic (the client) communicates with it. This is the ideal mode for development, as it allows for **hot-reloading** of your code in dynamic languages (like Python or PHP) without ever restarting the engine.

*   **Plugin Mode** For performance-critical tasks (like custom physics or complex AI), you can write logic in a systems language (like Rust or Zig) and load it directly into the engine as a high-speed plugin.

*   **Bundled Runtime** Once your game is complete, you package it with the **bundled runtime** for final distribution to players.

* * *

How Language-Agnosticism Works
---------------------------------

The "Client/Server" mode's language-agnosticism is made possible by its simple and efficient communication protocol. As you noted, the engine (server) and your game logic (client) communicate over standard, high-speed OS-level IPC:

*   **On macOS/Linux:** UNIX Domain Sockets

*   **On Windows:** Named Pipes


The data sent over this connection is not JSON or XML, but a tightly **packed binary stream** based on C-style data structures.

As long as a programming language has:

1.  Access to basic **socket libraries** (to connect to the pipe/socket).

2.  The ability to **pack and unpack binary data** (e.g., `pack()` in PHP, `struct.pack` in Python, or native abilities in C++/Rust).


...it can control the Phrost engine. The protocol consists of sending binary-packed command buffers (built by a `ChannelPacker`) to the engine and receiving binary-packed event and frame data back. This design, which is visible in the `IPCClient.php` and `PackFormat.php` files, is what allows any capable language to drive the engine.


* * *

Key Features
--------------

Phrost provides a complete toolset for 2D game development:

*   **Rendering:** Sprites (Animation, Sprite Sheets), Text, and basic Geometry (Lines, Points, Rectangles).

*   **Level Design:** Support for the **Tiled Map Editor** (Tilesets, Layers).

*   **Physics:** A built-in 2D physics engine (Dynamic/Static bodies, Rectangle/Circle colliders).

*   **Core Systems:** Audio, Texture Management, and a powerful Camera (Rotate, Translate, Zoom, Scale).

*   **Windowing:** Window control (Resize, Title, Fullscreen, Transparent, High DPI).

*   **Extensibility:** A powerful **plugin system** for loading high-performance modules written in **Rust** or **Zig**.


* * *

Current Language Support
---------------------------

This table shows which languages can use which integration mode.

| Language | Wrapper API | Embedded | Client (Hot-Reload) | Can Write Plugins | Bundle Distribution |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **PHP** | ✅ | ✅ | ✅ | | (coming soon) |
| **Python** | (WIP) | | ✅ | | |
| **JavaScript** | (Planned) | | ✅ | | |
| **Rust** | | | | ✅ | |
| **Zig** | | | | ✅ | |
