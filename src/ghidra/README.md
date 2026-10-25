
# Install Ghidra SRE Release (ghidra)

Install a Ghidra release from GitHub (latest or a specific version). Builds the native binaries on linux arm64 and checks the JDK against the release's application.java.min.

## Example Usage

```json
"features": {
    "ghcr.io/clearbluejar/features/ghidra:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| ghidra_version | Version of Ghidra to install | string | latest |
| ghidra_install_dir | Default Install Directory | string | /ghidra |
| username | Username to own the Ghidra install directory. | string | vscode |
| update_rc | Whether or not to persist GHIDRA_VERSION and GHIDRA_INSTALL_DIR in bashrc or zshrc | boolean | true |
| build_natives | Rebuild the Ghidra native binaries (decompile, sleigh, ...) from the shipped source even on platforms where the release provides them. Always done on linux arm64. To patch the decompiler see the ghidra-decompiler-patch feature. | boolean | false |


## Java version

Ghidra only starts on a JDK that satisfies `application.java.min` of the release (21 for 11.2 through 12.1.4,
25 from 12.2). The feature reads that value from the installed release and fails the build if the JDK on
`PATH` is too old (or too new, if the release sets `application.java.max`); if there is no JDK yet it only
warns. The feature declares `installsAfter` the `java` feature, so listing both is enough:

```json
"features": {
    "ghcr.io/devcontainers/features/java:1": { "version": "25", "installGradle": true },
    "ghcr.io/clearbluejar/features/ghidra:1": { "ghidra_version": "12.2" }
}
```

## Release lookup

Versions are resolved against the exact release tag (`Ghidra_<version>_build`), so `"12.1"` installs 12.1,
not 12.1.4. The GitHub API allows 60 unauthenticated requests per hour per IP; if many images build in
parallel from one address, pass a `GITHUB_TOKEN` build argument or environment variable and the feature
will use it. A failed lookup prints the API message and aborts the build.

## Native binaries

Ghidra releases ship native binaries (`decompile`, `sleigh`, GNU demangler) for x86_64 Linux, macOS and
Windows only. On linux arm64 this feature always rebuilds them from the source included in the release,
which needs `java` and `gradle` in the image. Install them with a feature that runs first:

```json
"features": {
    "ghcr.io/devcontainers/features/java:1": { "version": "21", "installGradle": true },
    "ghcr.io/clearbluejar/features/ghidra:1": { "ghidra_version": "12.2" }
},
"overrideFeatureInstallOrder": ["ghcr.io/devcontainers/features/java"]
```

## Patching the decompiler

See the [ghidra-decompiler-patch](../ghidra-decompiler-patch) feature, which layers on top of this one or on a prebuilt image.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/clearbluejar/features/blob/main/src/ghidra/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
