
# Patch and rebuild the Ghidra decompiler (ghidra-decompiler-patch)

Applies a patch to the decompiler C++ source shipped inside an existing Ghidra install and rebuilds the native binaries, so Ghidra runs the patched decompiler. Layer it on top of a prebuilt Ghidra image (e.g. ghcr.io/clearbluejar/ghidra-python). Bundles the diff-stable default variable name patch (NationalSecurityAgency/ghidra#10025).

## Example Usage

```json
"features": {
    "ghcr.io/clearbluejar/features/ghidra-decompiler-patch:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| patch | Bundled patch to apply. 'none' applies only patch_url. | string | diffstable-varnames |
| patch_url | URL of an additional unified diff (git format-patch, -p1 relative to the Ghidra install dir) applied after the bundled patch. | string | - |
| ghidra_install_dir | Ghidra install directory. Defaults to $GHIDRA_INSTALL_DIR from the image, then /ghidra. | string | - |

## What it does

Every Ghidra release ships the decompiler C++ source (`Ghidra/Features/Decompiler/src/decompile/cpp`) and a
`gradle buildNatives` task. This feature patches that source inside an existing install and rebuilds the native
binaries into `Ghidra/Features/Decompiler/build/os/<platform>/`, which Ghidra prefers over the shipped `os/`
directory. The rebuild takes about 20 s. The build fails if the patch does not apply to the installed
Ghidra version, rather than silently running the stock decompiler.

## Bundled patch: `diffstable-varnames`

Default local variable names are numbered per data-type prefix (`uVar1, uVar2, ... iVar1, iVar2, ...`) instead
of from one counter shared across all types. Adding or removing one variable then no longer renumbers every
other variable in the function, which removes most spurious churn when diffing decompiled output of two binary
versions (e.g. with [ghidriff](https://github.com/clearbluejar/ghidriff)). Proposed upstream in
[NationalSecurityAgency/ghidra#10025](https://github.com/NationalSecurityAgency/ghidra/pull/10025); once it
ships in a release this feature becomes a no-op for that version.

## Usage on a prebuilt image

```json
{
    "image": "ghcr.io/clearbluejar/ghidra-python:12.1.4ghidra3.13python-bookworm",
    "features": {
        "ghcr.io/clearbluejar/features/ghidra-decompiler-patch:1": {}
    }
}
```

Needs `java` and `gradle` in the image (the ghidra-python images have both). With a fresh Ghidra install in
the same devcontainer, list the java and ghidra features first:

```json
"features": {
    "ghcr.io/devcontainers/features/java:1": { "version": "21", "installGradle": true },
    "ghcr.io/clearbluejar/features/ghidra:1": { "ghidra_version": "12.1.4" },
    "ghcr.io/clearbluejar/features/ghidra-decompiler-patch:1": {}
},
"overrideFeatureInstallOrder": [
    "ghcr.io/devcontainers/features/java",
    "ghcr.io/clearbluejar/features/ghidra"
]
```

## Usage without the feature

`install.sh` is self-contained and downloads the bundled patch when run outside the feature directory, so it
also works as a post-create step or in a Dockerfile:

```json
"postCreateCommand": "curl -fsSL https://raw.githubusercontent.com/clearbluejar/features/main/src/ghidra-decompiler-patch/install.sh | sudo -E bash"
```

The feature form is preferred because the result is cached as an image layer; a `postCreateCommand` rebuilds
the natives every time the container is recreated.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/clearbluejar/features/blob/main/src/ghidra-decompiler-patch/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
