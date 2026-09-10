# Wallpapers

Original downloads are preserved unchanged. Filenames retain the Wallhaven ID
to connect each image to its source. Nix exposes one selected image per wallpaper
at `~/Pictures/Wallpapers`; choose the active image or rotation through DMS.

At rebuild time, Nix prefers a `-WIDTHxHEIGHT` variant matching the display
resolution declared in `modules/desktop/niri/default.nix`, with the same
extension as the original. Otherwise it uses the original. Other variants and
this catalogue are excluded. On Othinus, the collection contains seven images:
the `-2560x1440` Akame variant and the six other originals.

Use lowercase `.jpg`, `.jpeg`, `.png`, or `.webp` extensions and reserve the
trailing `-WIDTHxHEIGHT` suffix for variants. Generate each new resolution from
the original, keeping it unchanged as a reference.

| Original | Dimensions | Source |
| --- | --- | --- |
| `stellar-blade-eve-monochrome-6l2yzw.jpg` | 3840 × 2160 | [Wallhaven](https://wallhaven.cc/w/6l2yzw) |
| `stellar-blade-2b-vpod58.png` | 3840 × 2160 | [Wallhaven](https://wallhaven.cc/w/vpod58) |
| `nier-automata-dark-6o5qjl.jpg` | 3840 × 2160 | [Wallhaven](https://wallhaven.cc/w/6o5qjl) |
| `nier-automata-2b-a2-9s-gjlg2q.png` | 3840 × 2160 | [Wallhaven](https://wallhaven.cc/w/gjlg2q) |
| `nier-automata-yorha-285v3m.jpg` | 7680 × 4320 | [Wallhaven](https://wallhaven.cc/w/285v3m) |
| `neverness-to-everness-city-gwdvxq.jpg` | 3840 × 2160 | [Wallhaven](https://wallhaven.cc/w/gwdvxq) |
| `akame-95y5rk.png` | 1920 × 1080 | [Wallhaven](https://wallhaven.cc/w/95y5rk) |

When either original dimension is below 2560 × 1440, keep the original and add a
`-2560x1440` variant. Enlarge proportionally to cover the display, then center
crop any excess. Qualifying originals need no variant.

`akame-95y5rk-2560x1440.png` is the only resized variant in this collection.
It uses Lanczos resampling; its 16:9 aspect ratio requires no cropping.

```sh
magick wallpapers/akame-95y5rk.png -filter Lanczos -resize '2560x1440^' \
  -gravity center -extent 2560x1440 wallpapers/akame-95y5rk-2560x1440.png
```
