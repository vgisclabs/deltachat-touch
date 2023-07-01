# DeltaTouch

Messaging app for Ubuntu Touch, powered by deltachat-core. 

## Important notice to xenial (16.04) users

This is the main branch which now contains the focal version. Please checkout the xenial branch if you want to build for xenial.

## Important notice to focal (20.04) users

While the build instructions below also work for focal and the app is fully functional in the current state of focal, some internals of the click package currently refer to xenial (16.04) only. If you install it now, it may lead to problems later on when a dedicated focal version has been released to the Open Store. I will investigate this and post a solution, if necessary, so please keep an eye out on this.

Update: Seems it's no problem to update from the xenial to the focal version of the app on a focal device. Will confirm after further testing.

Update 2: Confirmed, no problems, users can safely update.

## Building

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

If the submodule has been cloned for the first time or its CMakeLists.txt has been modified by an update, it needs to be patched in order to work with clickable:

```
patch libs/deltachat-core-rust/CMakeLists.txt < libs/patches/dc_core_rust-CMakeLists.patch
```

Build the libdeltachat.so for your architecture (arm64 in this example, could also be armhf or amd64 if you want to use `clickable desktop`). This will take some time:

```
clickable build --libs deltachat-core-rust --arch arm64
```

### Build the app

Preqrequisite: libdeltachat.so has been built for your architecture as described above. Then build the app for your architecture (arm64 in this example, could also be armhf):

```
clickable build --arch arm64
```

This will give you a .click file in build/aarch64-linux-gnu/app or build/arm-linux-gnueabihf/app that you can send to your phone and install it via OpenStore (just click on it in the file manager).

### Test it on your PC

It's possible to run the app on a standard desktop computer. Prerequisite is that libdeltachat.so has been built for the architecture amd64. Then enter:

```
clickable desktop
```

For some options like dark mode or using a different language, see <https://clickable-ut.dev/en/latest/commands.html#desktop>.

Note that there are some limitations to `clickable desktop`:
- The resolution is quite low, so don't be surprised if it looks blurred. This will not the case on the phone.
- Anything requiring a service that's running in Ubuntu Touch will not work. As a consequence, file exchange will not be possible as it needs the so-called content hub which is not running on the desktop. This means:
    - Backups cannot be im- or exported, so accounts have to be set up via logging in to your account.
    - Images and sound files / voice recordings cannot be sent.
    - Attachments cannot be saved.

## License

Copyright (C) 2023  Lothar Ketterer

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License version 3, as published
by the Free Software Foundation.

In addition, as a special exception, the author of this program gives permission to link the code of its release with the OpenSSL project's "OpenSSL" library (or with modified versions of it that use the same license as the "OpenSSL" library), and distribute the linked executables. You must obey the GNU General Public License in all respects for all of the code used other than "OpenSSL". If you modify this file, you may extend this exception to your version of the file, but you are not obligated to do so. If you do not wish to do so, delete this exception statement from your version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranties of MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
