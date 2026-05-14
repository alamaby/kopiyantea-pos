# Inter Font Assets

Bundled (not CDN-loaded) per ADR-0013 and master prompt §2.12, §6.8.

**Action required before first build:** download Inter from <https://rsms.me/inter/> (SIL Open Font License) and place these four files here:

- `Inter-Regular.ttf` — weight 400
- `Inter-Medium.ttf` — weight 500
- `Inter-SemiBold.ttf` — weight 600
- `Inter-Bold.ttf` — weight 700

These paths are referenced by `pubspec.yaml`. The build will fail until the files are present.

License: keep `OFL.txt` from the Inter distribution alongside the font files.
