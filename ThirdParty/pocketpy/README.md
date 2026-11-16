# pocketpy

The scratch buffer runs Python on [pocketpy](https://github.com/pocketpy/pocketpy), a small Python 3 interpreter written in C.

- Version: v2.2.0
- Files: `pocketpy.c` and `pocketpy.h`, the single-file build from the [v2.2.0 release](https://github.com/pocketpy/pocketpy/releases/tag/v2.2.0), unmodified.
- License: MIT, in `LICENSE`. The app bundles the file as `Contents/Resources/LICENSE`.

To upgrade, download both files from a newer release, replace them here, and run `mise run test`.

`project.yml` compiles `pocketpy.c` with these settings:

- `PK_ENABLE_WATCHDOG=1`, so that a run that takes too long raises `TimeoutError`.
- `-w`, because the project does not fix warnings in vendored code.
