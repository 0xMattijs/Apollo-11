# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# Apollo-11 — Virtual AGC build & run environment
#
# Compiles the Virtual AGC toolchain from source:
#   * yaYUL    — the AGC assembler
#   * yaAGC    — the AGC CPU emulator
#   * yaDSKY2  — the DSKY display/keyboard GUI (wxWidgets)
#
# Then assembles the two Apollo 11 core ropes:
#   * Comanche055 — Command Module (CM) guidance computer program
#   * Luminary099 — Lunar Module (LM) guidance computer program
#
# The assembled ropes use the maintained, compilable Apollo 11 source bundled
# with the Virtual AGC toolchain. THIS repository's archival transcription has
# drifted and no longer assembles with the current yaYUL; it is copied in at
# /opt/apollo11 for reference/diffing (see `agc diff`).
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim

# Upstream Virtual AGC toolchain source (override with --build-arg to pin a ref)
ARG VAGC_REPO=https://github.com/virtualagc/virtualagc.git
ARG VAGC_REF=master

ENV DEBIAN_FRONTEND=noninteractive \
    VAGC=/opt/virtualagc \
    APOLLO=/opt/apollo11

# --- Build + runtime dependencies -----------------------------------------
#   build-essential/make/git : compile the toolchain
#   libncurses-dev           : yaAGC interactive debug console
#   libwxgtk3.2-dev          : yaDSKY2 GUI (wxWidgets 3.2)
#   x11 libs / tcl-tk        : GUI runtime bits
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates build-essential make pkg-config \
        libncurses-dev libwxgtk3.2-dev \
        libgtk-3-0 x11-utils \
    && rm -rf /var/lib/apt/lists/*

# --- Build the Virtual AGC toolchain (core tools + DSKY GUI only) ----------
# A full `make` also assembles ~30 historical missions; we only need the tools.
# Upstream warns NOT to parallelise (`make` copies shared files mid-build).
RUN git clone --depth 1 --branch ${VAGC_REF} ${VAGC_REPO} ${VAGC}
WORKDIR ${VAGC}
RUN make yaAGC yaYUL yaDSKY2

# --- Keep this repo's archival source for reference/diffing ----------------
# (It has drifted from the maintained source and no longer assembles with the
#  current yaYUL — see `agc diff`.  The ropes we build/run come from the
#  compilable Apollo 11 source bundled inside the Virtual AGC toolchain.)
COPY Comanche055 ${APOLLO}/Comanche055
COPY Luminary099 ${APOLLO}/Luminary099
COPY docker-entrypoint.sh /usr/local/bin/agc

# --- Assemble the canonical CM and LM core ropes ---------------------------
RUN chmod +x /usr/local/bin/agc && /usr/local/bin/agc assemble all

WORKDIR ${VAGC}
ENTRYPOINT ["/usr/local/bin/agc"]
CMD ["help"]
