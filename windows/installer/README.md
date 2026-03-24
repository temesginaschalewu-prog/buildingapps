Place `VC_redist.x64.exe` in this folder before building the installer if you want older Windows machines to receive the Microsoft Visual C++ runtime automatically during install.

Build flow:
1. `flutter build windows --release`
2. Open `FamilyAcademy.iss` in Inno Setup
3. Build the installer

If `VC_redist.x64.exe` is present, the installer runs it silently first.
