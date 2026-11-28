# Kovy documentation site

Static site generator and viewer for the Kovy language reference. It renders
the Markdown tree in [`../docs`](../docs) into a self-contained site with
client-side search, dark/light themes, syntax highlighting, canonical URLs,
Open Graph metadata and a sitemap.

There is no Node.js or front-end framework: the generator is Python, the output
is plain HTML/CSS/JS.

## Build

```bash
python3 -m pip install -r docs-site/requirements.txt
python3 docs-site/build.py
```

The site is written to `docs-site/site/` (ignored by git). Useful flags:

```bash
python3 docs-site/build.py \
  --docs docs \
  --out docs-site/site \
  --base-url https://xlebore3o4ka.github.io/kovy-lang \
  --version 0.1 \
  --build-date 2026-11-28
```

`--base-url` is also read from `KOVY_SITE_URL`; it is used for canonical
links, Open Graph URLs, the sitemap and `robots.txt`.

## Preview

```bash
docs-site/serve.sh
# http://127.0.0.1:8765
```

## Validate

```bash
python3 docs-site/check_site.py docs-site/site
```

The check verifies required files, internal links and assets, canonical and
Open Graph metadata, search-index targets, the sitemap and `robots.txt`.

## Assets

The header logo is theme-specific and transparent:

```bash
python3 docs-site/make_logos.py   # design/orange_logo_{1,2}.png -> assets/logo-{light,dark}.png
python3 docs-site/make_og_image.py  # assets/og-image.png (1200x630)
```

The browser favicon intentionally stays `assets/favicon.png`.

## Layout

```text
docs-site/
├── build.py            # static site generator
├── check_site.py       # post-build validation
├── make_logos.py       # transparent theme logos
├── make_og_image.py    # Open Graph card
├── serve.sh            # local preview server
├── requirements.txt
├── assets/             # CSS, JS, logos, favicon, social card
├── design/             # source logo PNGs
└── site/               # generated output, not committed
```

## Deployment

`.github/workflows/docs.yml` builds the site and publishes it to GitHub Pages
on every push to `master`. Enable **Settings → Pages → Source: GitHub Actions**
once in the repository settings.