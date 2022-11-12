## Copyrights

[eSpeak-NG](https://github.com/espeak-ng/espeak-ng) is an open source speech synthesis module, forked from open source [eSpeak](http://sourceforge.net/projects/espeak/files/espeak/) software. Please refer these projects to ensure its copyrights.

The iOS/macOS port was originated by Yury Popov ([@djphoenix](https://github.com/djphoenix)) in 2022.

## Licensing

The iOS/macOS port are separated to two modules.

The first (called Extension) is [Audio Unit Application Extension](https://developer.apple.com/documentation/audiotoolbox/audio_unit_v3_plug-ins), that links statically with `libespeak-ng` library. As `espeak-ng` licensed under GPLv3, Extension inherits it too. So **all Extension code is licensed under [GPLv3](LICENSE.GPL.txt)**.

The second module (called Application) is an user-interface frontend. It does not linked with `libespeak-ng` nor Extension, and communicates with Audio Unit with XPC. So it **does not** inherits a GPLv3 license. For possible reuse its code with other synthesizing libraries, **all Application code is licensed under [MIT license](LICENSE.MIT.txt)**

As both modules are contained in single Xcode project, `xcodeproj` and related files is licensed under GPLv3.
