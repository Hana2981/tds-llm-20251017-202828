# Captcha Solver (Client-side OCR)

MIT-licensed, single-page web app to OCR simple captcha images. It accepts an image URL via the `?url=` query parameter and uses Tesseract.js with smart preprocessing to extract text directly in your browser. No server required.

Note: This demo targets simple, text-based captchas. Modern captchas deliberately resist OCR and may not work reliably.

## Overview

- Client-side only: HTML + JS + CSS.
- Accepts `?url=https://.../image.png` and displays that image.
- Performs preprocessing (grayscale, Otsu thresholding, despeckling, upscaling, auto-invert) to improve OCR.
- Uses Tesseract.js with constrained settings (PSM 7, alphanumeric whitelist) for faster and more accurate results.
- Handles CORS for remote images via a fetch fallback and a permissive CORS proxy, when needed.
- Ships with a default, embedded sample if no URL is provided.

## Setup

No build or server needed.

1. Download the two files in this repository:
   - index.html
   - README.md
2. Open `index.html` in any modern browser with internet access (to load Tesseract.js from CDN).

That’s it.

## Usage

- Open the app and it will:
  - Load the captcha image from `?url=...` if provided, or
  - Fallback to a bundled sample image.
- The page shows:
  - Original image,
  - Preprocessed image,
  - Progress and logs,
  - The OCR result.
- Buttons:
  - Load image: fetches a new URL from the input box.
  - Solve OCR: re-runs recognition on the current image.
  - Use default sample: loads the embedded sample.

Examples:
- index.html?url=https://dummyimage.com/150x50/ffffff/000000.png&text=AB12
- index.html?url=https://your-domain.tld/path/to/captcha.png

Tips:
- If the remote server blocks CORS, the app tries a permissive proxy automatically. If OCR still fails, download the image and use a data URL or a CORS-enabled host.
- Keep the image relatively small; the app upscales as needed.

## License

MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.