
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
not 12.1.4. The GitHub API is tried first (a `GITHUB_TOKEN` environment variable, if present, lifts the
60 requests/hour unauthenticated limit). If the API call fails, typically rate-limited when many images build
in parallel from shared CI runner IPs, the asset is resolved from the release page on github.com instead,
which has no API quota. Only when both fail does the build abort with the reason.

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
