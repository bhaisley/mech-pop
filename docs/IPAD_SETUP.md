# Run on an iPad

MECH★POP has been development-signed, installed and played on an iPad Air (4th generation). A physical iPad build is created with **Godot 4.7.2 Standard**, its matching iOS export template, and **Xcode**.

1. Connect and trust your iPad in Xcode. Enable Developer Mode on the device if required.
2. Sign in to your Apple account in Xcode and select your own development team.
3. Open the `iPad` export preset in Godot. Set your team identifier and a bundle identifier registered for your project.
4. Export the Xcode project to a local `builds/ipad/` folder.
5. Open the project in Xcode, select the connected iPad, resolve signing with your team, and run.

The helper `tools/build_ipad.py` can automate export and compilation with the team and bundle identifiers you supply. Run it with `--help` for its arguments. Provisioning profiles, signing keys and a personally signed iPad app are not included in this public repository.

For LAN play, allow the game's Local Network permission. Launch **Play / Pop Rush** and choose **Touch**, **Bot** or a connected controller from each player's Input button. Touch provides a movement stick and separate Jump, Light, Break, Special, Dodge and Salvage buttons.

The user confirmed Xbox gameplay controls in an earlier preview and Touch/Bot/Xbox input selection in build 16. Broader simultaneous-touch, backgrounding and reconnection checks remain listed in [testing](TESTING.md).
