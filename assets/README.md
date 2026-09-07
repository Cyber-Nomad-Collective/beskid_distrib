# Installer assets

Branding used by the per-platform installers. All assets are derived from the
canonical Beskid logos living in the `beskid_vscode` submodule:

- `beskid-logo.svg` — copy of `beskid_vscode/media/beskid-logo.svg` (source).
- `beskid-512.png` — copy of `beskid_vscode/icon.png` (512×512 source raster).

## Regenerating derived formats

The Windows `.ico` is derived from the 512px source. In CI, the `windows-msi`
job generates `beskid.ico` from `beskid-512.png` using
ImageMagick (`magick beskid-512.png beskid.ico`) so the binary `.ico` is not
checked in. To regenerate locally:

```sh
# .ico (multi-resolution Windows icon)
magick assets/icons/beskid-512.png -define icon:auto-resize=256,128,64,48,32,16 \
  assets/icons/beskid.ico

```

If ImageMagick is unavailable, `beskid-512.png` can be used directly by the
WiX `<Icon>` element (Windows scales it as needed).
