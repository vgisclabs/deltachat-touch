# DeltaTouch

Messaging app for Ubuntu Touch, powered by deltachat-core. 

## Building

### General

The standard tool to build Ubuntu Touch apps is clickable. For this, either docker or podman need to be installed. Then the python package `clickable-ut` (**not** 'clickable') can be installed via pip. For more instructions regarding the installation of clickable, see <https://clickable-ut.dev> and <https://ubports.gitlab.io/marketing/education/ub-clickable-1/trainingpart1module1.html#_on_your_ubuntu_touch_phone>.

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

Build the app for your architecture (arm64 in this example, could also be armhf):

```
clickable build --arch arm64
```

This will give you a .click file in build/aarch64-linux-gnu/app or build/arm-linux-gnueabihf/app that you can send to your phone and install it via OpenStore (just click on it in the file manager).

## License

Copyright (C) 2023  Lothar Ketterer

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License version 3, as published
by the Free Software Foundation.

In addition, as a special exception, the author of this program gives permission to link the code of its release with the OpenSSL project's "OpenSSL" library (or with modified versions of it that use the same license as the "OpenSSL" library), and distribute the linked executables. You must obey the GNU General Public License in all respects for all of the code used other than "OpenSSL". If you modify this file, you may extend this exception to your version of the file, but you are not obligated to do so. If you do not wish to do so, delete this exception statement from your version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranties of MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
