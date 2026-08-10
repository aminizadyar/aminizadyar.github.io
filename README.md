# aminizadyar.github.io

Personal academic website of Amin Izadyar — PhD candidate in Finance, Imperial College London.

Static HTML and CSS with no build step and no JavaScript. Open `index.html` in a browser
to preview locally, or serve the folder with `python -m http.server` if you want
root-absolute paths (`/assets/...`) to resolve exactly as they do in production.

Pushing to `main` triggers [.github/workflows/pages.yml](.github/workflows/pages.yml),
which copies the site files to the `gh-pages` branch that GitHub Pages serves.

## Layout

| Path | Purpose |
| --- | --- |
| `index.html` | The entire site: hero, working papers, about, contact, plus SEO metadata and JSON-LD |
| `assets/css/style.css` | All styling; palette and metrics live in the `:root` custom properties |
| `assets/images/avatar.jpg` | Profile photo (512×512, also used as the Open Graph image) |
| `favicon.svg`, `favicon*.png`, `favicon.ico`, `apple-touch-icon.png` | "AI" monogram icon set, generated to match the site palette |
| `sitemap.xml`, `robots.txt` | Search-engine metadata; bump `lastmod` when content changes meaningfully |
