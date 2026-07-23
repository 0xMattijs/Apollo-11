# Building & running the Apollo 11 AGC code with Docker

This repository ships the original Apollo 11 Apollo Guidance Computer (AGC)
source code. To *assemble* and *run* it you need the [Virtual AGC][vagc]
toolchain. The included `Dockerfile` builds that toolchain, assembles the Apollo
11 Command Module and Lunar Module core ropes, and can run them in the emulator
— so you don't have to install anything on your host except Docker.

What the image contains:

| Tool | Purpose |
| --- | --- |
| `yaYUL` | The AGC assembler — turns `.agc` source into a binary core rope |
| `yaAGC` | The AGC CPU emulator — executes a core rope |
| `yaDSKY2` | The DSKY (Display/Keyboard) GUI the astronauts used to talk to the AGC |

## Which source gets assembled

> **Important.** The ropes the image assembles and runs come from the
> **maintained, compilable Apollo 11 source that ships inside the Virtual AGC
> toolchain**, not from the `.agc` files in *this* repository.
>
> This repository is a *historical archive*: its transcription has drifted over
> years of fidelity-focused PRs (renamed files, a restructured `MAIN.agc`,
> stripped assembler annotations) and no longer assembles with the current
> `yaYUL` — the Command Module source is one spurious error away, and the Lunar
> Module source produces thousands. Both are the *same programs* as the
> canonical source, so the canonical ropes are what you actually want to run.
>
> This repo's files are still copied into the image at `/opt/apollo11` for
> reference. Use `agc diff cm` / `agc diff lm` to see how they differ from the
> buildable source.

The two programs:

* **Comanche055** → Command Module (CM) — `cm`
* **Luminary099** → Lunar Module (LM) — `lm`

## Build the image

```bash
docker build -t apollo-agc .
```

This clones the upstream Virtual AGC toolchain, compiles `yaYUL`, `yaAGC` and
`yaDSKY2`, then assembles both core ropes (each a 73 728-byte binary).

## Assemble (verify the ropes compile)

Assembly already ran during the build, but you can re-run it any time:

```bash
docker run --rm apollo-agc assemble all   # both ropes
docker run --rm apollo-agc assemble lm    # Lunar Module only
docker run --rm apollo-agc assemble cm    # Command Module only
```

Each run reports the size of the produced `MAIN.agc.bin`.

## Run the emulator headless

Runs the AGC CPU with no GUI and drops you at the `yaAGC` monitor prompt
(`(agc)`). Useful to confirm the rope boots. Press `Ctrl-C` to stop.

```bash
docker run --rm -it apollo-agc emulator lm
```

## Run with the DSKY GUI (X11)

The DSKY panel is a graphical app, so the container needs access to an X server.

### Linux host

```bash
xhost +local:docker    # allow the container to reach your X server
docker run --rm -it \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    apollo-agc run lm            # or: run cm
xhost -local:docker    # revoke access when done
```

`run` starts `yaAGC` with the selected rope and opens the matching `yaDSKY2`
panel, connected over the internal socket (TCP 19697). Closing the DSKY window
stops the emulator. (Without an X server, `run` prints instructions and keeps
`yaAGC` running headless.)

### macOS host (XQuartz)

1. Install and start [XQuartz], then in *XQuartz → Settings → Security* enable
   *Allow connections from network clients*.
2. `xhost + 127.0.0.1`
3. Run with the display pointed at the host:

   ```bash
   docker run --rm -it -e DISPLAY=host.docker.internal:0 apollo-agc run lm
   ```

### Windows host

Run an X server such as [VcXsrv] (start it with *Disable access control*), set
`DISPLAY` to your host IP, and pass `-e DISPLAY=<host-ip>:0.0`.

## Other commands

```bash
docker run --rm -it apollo-agc shell         # bash shell inside the image
docker run --rm apollo-agc yaYUL --help      # raw assembler
docker run --rm apollo-agc dsky lm           # only the DSKY (connect to a yaAGC)
docker run --rm apollo-agc diff cm           # archival vs. canonical source
docker run --rm apollo-agc help              # command summary
```

## Notes

* The toolchain source is pinned by the `VAGC_REF` build arg (defaults to
  `master`). To pin a specific upstream revision:
  `docker build --build-arg VAGC_REF=<commit> -t apollo-agc .`
* The image builds only `yaYUL`, `yaAGC` and `yaDSKY2` — not the full Virtual
  AGC suite (which also assembles ~30 other historical missions) — to keep build
  time and image size down.

[vagc]: https://www.ibiblio.org/apollo/
[XQuartz]: https://www.xquartz.org/
[VcXsrv]: https://sourceforge.net/projects/vcxsrv/
