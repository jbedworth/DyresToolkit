# Dyre's Toolkit logo

Original vector artwork: a heavy gold gear whose dark hub shows a fine layout
grid crossed by red center lines (the toolkit's grid), on a rich dark-brown
background. It shares its frame and colors with the other Dyre's logos. The
design has no font or external-image dependencies.

- `dyres-toolkit-logo.svg`: editable, resolution-independent source.
- `dyres-toolkit-logo.png`: 1024 x 1024 PNG master.
- `dyres-toolkit-logo-512.png`: 512 x 512 PNG for square project images.

The PNGs are rendered from the SVG with headless Chrome, for example:

```sh
chrome --headless=new --hide-scrollbars --window-size=1024,1024 --force-device-scale-factor=0.5 --screenshot=dyres-toolkit-logo-512.png dyres-toolkit-logo.svg
```

Use these files for project pages and distribution branding. Keep this
directory out of the runtime release ZIP; the TOC uses a built-in client icon
(INV_Misc_Wrench_01).
