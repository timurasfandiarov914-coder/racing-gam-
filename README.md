# STREETLINE: OPEN ROAD

An original, free, Android-first 3D street-racing prototype. The visual direction takes inspiration from arcade street racing, while the project uses its own name and a procedural placeholder car and environment.

> **Current stage: first playable foundation.** The car and city are procedural blockouts. This is not yet a finished realistic racing game, and no APK has been built or device-tested from this repository.

## Current prototype

- Godot 4 project configured for the Mobile renderer.
- Procedural asphalt highway, lane markings, guardrails, distant city blocks, and a daylight sky.
- Blue placeholder sports car with a simple rigid-body arcade controller, wheel visuals, and a following camera that pulls back and widens its field of view at speed.
- On-screen touch controls for steering, brake, throttle, and nitro.
- Keyboard fallback for desktop testing: WASD / arrow keys; Space or Down to brake; Shift for nitro.
- Speed readout, distance counter, and recharging nitro meter.
- No paid plugins, online services, or third-party assets required for this initial stage.

## Open the project

1. Install the official Godot Android editor on an Android device, or use Godot 4 on a desktop later if one becomes available.
2. Download this branch as a ZIP and extract it on the device.
3. In Godot, import the folder that contains the project.godot file.
4. Open the project and run scenes/main.tscn or press **Run Project**.

The project is currently a source project, not an installable APK. Android export templates and an export preset still need to be configured and tested before publishing a build.

## Technical direction

- Engine: Godot 4.x.
- Renderer: Mobile.
- Target device for early profiling: Google Pixel 6 Pro.
- First performance target: stable 30 FPS, then test 60 FPS.
- First milestone: validate vehicle feel, chase camera, touch controls, and mobile rendering before importing heavier assets.

## Planned next milestones

1. Verify the project opens and runs in the Android editor.
2. Tune car physics and the camera using real device testing.
3. Replace the procedural car with a properly licensed, optimized 3D model and PBR materials.
4. Improve road and building assets, traffic, sound, and visual effects.
5. Add races, weather/time-of-day progression, police pursuits, and garage progression.
6. Set up Android export and produce a test APK.

## Important limitations

The current car shape is deliberately a placeholder made from primitive meshes. The controller is arcade-oriented, not a complete simulation of suspension, tires, gearbox, or differential. The environment is a finite test highway with procedural buildings. Realistic assets, traffic AI, police behavior, audio, damage, rain, night lighting, and release packaging are future work.

## License and asset policy

No third-party models or textures are bundled at this stage. When external assets are added, their license and redistribution terms must be checked and documented.
