# Red Hat OpenShift Dev Spaces (formerly CodeReady Workspaces) Plugin Registry

This repository provides ready-to-use plugins for various languages and technologies as part of the embedded [Open VSX](https://open-vsx.org/about) registry.  
It is designed to support **air-gapped, offline, and proxy-restricted environments**.  

The embedded Open VSX registry includes only a curated subset of extensions published on [open-vsx.org](https://open-vsx.org), which are compatible with the **Microsoft Visual Studio Code – Open Source IDE**.

---

## Local Plugin Registry Build Process

To build the plugin registry, use the `build.sh` script.  

- The default **Open VSX** version used is defined in `build-config.json`.  
- The `build-config.json` file also specifies the **Che Code** version, which is used to ensure that published extensions are compatible with the editor version.

---

## List of Extensions

The list of Microsoft Visual Studio Code extensions is defined in the `openvsx-sync.json` file.  
To add or remove extensions, update this file accordingly.  

---

## Updating Extension Versions

To update the versions of existing extensions listed in `openvsx-sync.json`:  

1. Navigate to the `./build/scripts` directory.  
2. Run the `update_extensions_versions.sh` script.  

The script reads the editor version from `build-config.json` and retrieves the latest compatible version for each extension in the list.  

---

## License

Red Hat OpenShift Dev Spaces is open sourced under the Eclipse Public License 2.0.
