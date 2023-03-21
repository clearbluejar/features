
# Install Ghidra SRE Release (ghidra)

A feature to install the latest or specified Ghidra version from GitHub releases

## Example Usage

```json
"features": {
    "ghcr.io/clearbluejar/ghidra-feature/ghidra:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| ghidra_version | Version of Ghidra to install | string | latest |
| ghidra_install_dir | Default Install Directory | string | /ghidra |
| username | Username to own the Ghidra install directory. | string | vscode |
| update_rc | Whether or not to persist GHIDRA_VERSION and GHIDRA_INSTALL_DIR in bashrc or zshrc | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/clearbluejar/ghidra-feature/blob/main/src/ghidra/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
