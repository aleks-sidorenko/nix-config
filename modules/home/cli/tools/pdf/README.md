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

Resizing only changes page geometry; embedded images are kept as is, so the
file does not get smaller. To reduce file size, see below.

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

Override the preset's image resolution for anything in between; 100 dpi is
usually still readable for scanned documents:

```sh
gs -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook \
   -dColorImageResolution=100 -dGrayImageResolution=100 \
   -o small.pdf in.pdf
```

### Below a target size

Ghostscript has no target-size option, so step the resolution down until the
output fits (POSIX sh; from fish, run it inside `bash`):

```sh
max=$((10 * 1024 * 1024))   # 10 MiB
for dpi in 150 120 100 85 72 60 50; do
  gs -q -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook \
     -dColorImageResolution=$dpi -dGrayImageResolution=$dpi \
     -o small.pdf in.pdf
  size=$(wc -c < small.pdf)
  echo "$dpi dpi: $size bytes"
  [ "$size" -le "$max" ] && break
done
```

If even 50 dpi is too big, the bulk is not images (fonts, vector content) or
the pages need splitting across files.

## Combine and shrink in one step

```sh
gs -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -o out.pdf a.pdf b.pdf
```
