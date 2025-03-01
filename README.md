# DeltaTouch

Messaging app powered by deltachat-core. Originally for Ubuntu Touch, it is now also available on Nix (and more, see wiki).

<img alt="Screenshot Chat List" src="extra/images/chatlist.png" width="374" /> <img alt="Screenshot Chat View" src="extra/images/chatview.png" width="374" />

## Branches

* main: Ubuntu Touch 20.04 (focal), Nix, Droidian, Mobian and general development. In other words, everything **except** Ubuntu Touch 16.04 (xenial). Contributions should be based on main.
* xenial: Ubuntu Touch 16.04 (xenial).
* Other branches are for development of specific features that are not ready for usage yet.


## Infos regarding the Nix package


Difference(s) to the Ubuntu Touch version:

* File im- and export is managed via QML FileDialog instead of the Ubuntu Touch specific ContentHub.

Currently, some things are broken in the Nix package:

* Recording voice messages may fail due to missing codec
* Playing audio files may not work
* Camera does not work
* Most emojis are not displayed

## Building for Ubuntu Touch 20.04 (focal)

### General

The standard tool to build Ubuntu Touch apps is clickable. For this, either docker or podman need to be installed. Then the python package `clickable-ut` (**not** 'clickable') can be installed via pip. For more instructions regarding the installation of clickable, see <https://clickable-ut.dev> and <https://ubports.gitlab.io/marketing/education/ub-clickable-1/trainingpart1module1.html>.

Clone this repo:

```
git clone https://codeberg.org/lk108/deltatouch
```

### Building libdeltachat.so

Activate/update the deltachat-core-rust submodule:

```
cd deltatouch
git submodule update --init --recursive
```

Build libdeltachat.so for your architecture (arm64 in this example, could also be `armhf`, or `amd64` if you want to use `clickable desktop`). This will take some time:

```
clickable build --lib deltachat-core-rust --arch arm64
```

### Buidling libquirc.so.1.2

Activating/updating the quirc submodule should have already been done by running `git submodule update --init --recursive` for libdeltachat.so above.

Build libquirc.so.1.2 for your architecture (arm64 in this example, could also be `armhf` or `amd64` if you want to use `clickable desktop`):

```
clickable build --lib quirc --arch arm64
```


### Build the app

Preqrequisite: libdeltachat.so and libquirc.so.1.2 have been built for your architecture as described above. Then build the app for your architecture (`arm64` in this example, could also be `armhf`):

```
clickable build --arch arm64
```

This will give you a .click file in build/aarch64-linux-gnu/app or build/arm-linux-gnueabihf/app that you can send to your phone and install it via OpenStore (just click on it in the file manager).

### Test it on your PC

With some restrictions, it's possible to run the app on a standard desktop computer. Prerequisite is that libdeltachat.so and libquirc.so.1.2 have been built for the architecture amd64. Then enter:

```
clickable desktop
```

For some options like dark mode or using a different language, see <https://clickable-ut.dev/en/latest/commands.html#desktop>.

Limitations to `clickable desktop` are:
- The resolution is quite low, so don't be surprised if it looks blurred. This will not be the case on the phone.
- Anything requiring a service that's running in Ubuntu Touch will not work. As a consequence, file exchange will not be possible as it needs the so-called ContentHub which is not available on the desktop. This means:
    - Backups cannot be im- or exported, so accounts have to be set up via logging in to your account or by adding as second device (if the camera doesn't work, copy the code from the QR to the clipboard and paste from clipboard).
    - Images and sound files cannot be attached.
    - Attachments cannot be saved.
    - It may not be possible to use a potentially present camera for QR code scanning.

## License

Copyright (C) 2023, 2024  Lothar Ketterer

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License version 3, as published
by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranties of MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

## Sponsors

The project to bring [Webxdc](https://webxdc.org) to DeltaTouch is generously funded by the [NLnet foundation](https://nlnet.nl) through the [NGI0 Entrust fund](https://nlnet.nl/project/DeltaTouch/).
