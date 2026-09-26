# Installer assets

Branding used by the per-platform installers. All assets are derived from the
canonical Ridge geometry in `site/beskid_brand` in the parent checkout:

- `beskid-logo.svg` — generated Emerald Ridge SVG.
- `beskid-512.png` — generated 512×512 Ridge raster.

Regenerate checked-in artwork from the parent checkout with
`pnpm --dir site/beskid_brand sync:assets`.

## Regenerating derived formats

The Windows `.ico` is derived from the 512px source. In CI, the Woodpecker Windows
pipeline generates `beskid.ico` from `beskid-512.png` using
ImageMagick (`magick beskid-512.png beskid.ico`) so the binary `.ico` is not
checked in. To regenerate locally:

```sh
# .ico (multi-resolution Windows icon)
magick assets/icons/beskid-512.png -define icon:auto-resize=256,128,64,48,32,16 \
  assets/icons/beskid.ico

```

If ImageMagick is unavailable, `beskid-512.png` can be used directly by the
WiX `<Icon>` element (Windows scales it as needed).
