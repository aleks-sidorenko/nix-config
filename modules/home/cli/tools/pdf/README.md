# PDF tools

`nix-config.cli.tools.pdf` installs [pdfcpu](https://pdfcpu.io) and
[Ghostscript](https://www.ghostscript.com). Enabled by the `media` role.

## Combine

```sh
pdfcpu merge out.pdf a.pdf b.pdf c.pdf   # in argument order
pdfcpu merge out.pdf *.pdf               # shell glob order
pdfcpu merge -s out.pdf *.pdf            # sorted by file name
```

## Resize pages

```sh
pdfcpu resize "form:A4" in.pdf out.pdf            # paper size: A4, A5, Letter, Legal, …
pdfcpu resize "form:A4L" in.pdf out.pdf           # landscape
pdfcpu resize "scale:0.5" in.pdf out.pdf          # scale by factor
pdfcpu resize -u mm "dim:210 297" in.pdf out.pdf  # explicit width/height (default unit: points)
```

`pdfcpu info in.pdf` shows page count and sizes.

## Shrink file size

pdfcpu cannot downsample images, so use Ghostscript:

```sh
gs -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -o small.pdf in.pdf
```

| Preset      | Image DPI | Use                     |
| ----------- | --------- | ----------------------- |
| `/screen`   | 72        | smallest, screen only   |
| `/ebook`    | 150       | good default            |
| `/printer`  | 300       | print quality           |
| `/prepress` | 300       | print, preserves colour |

## Combine and shrink in one step

```sh
gs -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -o out.pdf a.pdf b.pdf
```
