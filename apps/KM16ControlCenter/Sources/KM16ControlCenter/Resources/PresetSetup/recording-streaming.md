# Recording & Streaming: OBS Studio

This preset launches OBS Studio (`com.obsproject.obs-studio`) and sends controls through OBS WebSocket v5. Pressing the main dial changes the local software profile. Install OBS and configure its scenes before continuing.

1. In OBS, open Tools > WebSocket Server Settings, enable the server, choose a password, and note the port. The usual local endpoint is `ws://127.0.0.1:4455`; use the values shown by OBS if they differ.
2. In KM16 Control Center's Connections view, enter that WebSocket URL and password.
3. Enter the exact OBS Audio Mixer input name for the microphone control and the exact input name for desktop or playback audio.
4. Arrange the current OBS scene collection in the desired order. Scene 1 through Scene 8 address the first eight scenes from top to bottom in OBS's Scenes list; a missing slot produces an error.
5. Enable and start OBS's Replay Buffer before using Save replay. Pause and Resume require an active recording format/output that supports pausing. Transition requires Studio Mode.
6. Test scene selection and audio changes before a live session. Test start, pause, resume, and stop with a disposable local recording.

Scene keys and the main dial switch the current Program scene directly, including in Studio Mode. Transition separately sends the current Preview scene to Program.

Audio rotations change the configured input by five percentage points and keep KM16 Control Center's range between 0 and 100 percent. OBS can represent amplified input volumes above 100 percent, but the preset does not use that range. It also does not start streaming or create scenes, inputs, recording paths, or credentials.

References:

- [OBS Studio macOS installation](https://obsproject.com/kb/mac-installation)
- [OBS WebSocket protocol](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md)
- [OBS frontend recording, replay, scene, and Studio Mode APIs](https://docs.obsproject.com/reference-frontend-api)
- [OBS macOS bundle declaration](https://github.com/obsproject/obs-studio/blob/master/cmake/macos/helpers.cmake)
