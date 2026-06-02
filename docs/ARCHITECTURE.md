# Hotblock Architecture

Hotblock is now scoped to a very simple flow:

1. The user adds websites to a list.
2. The user presses Start.
3. When a blocked website is visited, Hotblock speaks a focus warning.

## Current app shell

The native macOS app currently covers:

- Website list management
- Start and stop blocking state
- Spoken warning behavior
- A test action that simulates visiting a blocked site

## Next implementation step

To detect real website visits automatically in Safari, this project should add a Safari web extension target. Apple documents Safari web extensions as the way to extend Safari behavior and block or react to web content in Safari.
