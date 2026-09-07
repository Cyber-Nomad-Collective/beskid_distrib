# Classic confinement request: `beskid`

Copy this request to the [Snapcraft Forum Store requests category](https://forum.snapcraft.io/c/store-requests/10) while signed in as the publisher that owns the `beskid` Snap Store entry. Replace the bracketed publishing-account detail before posting.

## Request

Please grant classic confinement to the `beskid` snap (Snap Store revision 1, version `0.1.77`).

`beskid` is an AOT compiler, programming-language toolchain, command-line runner, and language server for Beskid projects. It distributes the `beskid` compiler CLI and `beskid-lsp` binaries for x86_64 Linux.

Classic confinement is required for the compiler workflow, not merely to package prebuilt binaries:

- developers invoke Beskid from arbitrary project directories and it reads, writes, and builds the project tree selected by the user;
- `beskid run` executes the program the user just compiled, so it must launch user-defined local executables from that project environment;
- host composition and development workflows interact with user-selected local tools and files rather than a fixed, snap-owned workspace.

The snap does not provide device management, privileged installation, direct `sudo`/`pkexec` access, or background system administration. It is a user-invoked compiler and programming-language tool. Users install it explicitly with `snap install beskid --classic`.

Publisher: [Ubuntu One / organisation owning the `beskid` snap]

Source and packaging definition: <https://github.com/Cyber-Nomad-Collective/beskid/tree/main/beskid_distrib/snap>

Thank you for reviewing the request. We will link this forum thread from the rejected revision review and follow any additional verification guidance.
