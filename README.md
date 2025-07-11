# Zzz

[<img src="/static/logo.svg" alt="three sleepy z's" align="right" width="192" height="192">](https://www.zzz.software/)

> fullstack toolkit for adaptive web environments 💤 nice web things

⚠️ early pre-release, does not persist your data yet

**[zzz.software](https://www.zzz.software/)**

Zzz, pronounced "zees" like bees,
is a fullstack toolkit for adaptive web environments.
The idea is to make a cross-platform software environment that adapts to your needs and intent
while remaining fully open, aligned, and in your control. It's a flexible toolkit
for consuming and creating content, developing web software,
and crafting experiences with uncompromising UX and DX.

This is an early stage project and the ideas are still developing -
see the issues and [discussions](https://github.com/ryanatkn/zzz/discussions)
or @ me on [Bluesky](https://bsky.app/profile/ryanatkn.com).

More at [zzz.software/about](https://www.zzz.software/about).

## Setup

This project is in its early stages, and installing it
currently requires some basic technical skills.
Eventually there will be a desktop app but
for now you'll need Node 22.15+ (YMMV with Deno/Bun/etc)
and Git to clone the repo.

Zzz is deployed via SvelteKit's static adapter with diminished capabilities.
([zzz.software](https://www.zzz.software/))

> Windows probably doesn't work but will be supported - help is appreciated.
> For now I recommend [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

First set up an `.env` file in your project root:

- see [src/lib/server/.env.example](/src/lib/server/.env.example)
  - add to `.env` or `.env.development` and `.env.production` -
    `SECRET_ANTHROPIC_API_KEY`, `SECRET_OPENAI_API_KEY`, `SECRET_GOOGLE_API_KEY`

Then in your terminal:

```bash
npm run dev
```

Browse to the location is says, probably `localhost:5173`.

## Roadmap

- [#7 integrate database](https://github.com/ryanatkn/zzz/issues/7)
- [#8 undo/history system](https://github.com/ryanatkn/zzz/issues/8)
- publish to npm
- input welcome

## Credits 🐢<sub>🐢</sub><sub><sub>🐢</sub></sub>

Zzz builds on a great deal of software.

- see the deps in [package.json](package.json)
- I started using [Claude](https://claude.ai/) after making the initial prototype,
  and and I've continued to use it to varying but sufficient success
  to shape its outputs into my usual style
  - I'm meticulous with most things,
    but there's low quality slop in lower prioritity areas like tests and peripheral utilities
  - search for `// @slop` to see them, I'll make a UI to document this data soon
  - I care about the interfaces and general patterns of `// @slop` modules like all other code,
    but slop module internals may be low quality,
    and in general they should be less trusted for correctness and style
  - for the important parts, I consider the code quality up to par with my norm
    (my normal being [Fuz](https://github.com/ryanatkn/fuz)/[Moss](https://github.com/ryanatkn/moss)/[Gro](https://github.com/ryanatkn/gro)/[Belt](https://github.com/ryanatkn/belt)),
    with the caveat that this initial proof of concept
    is intentionally slapdash in places for speed and to experiment,
    and LLMs make this mindset easy to indulge,
    so there's a higher quantity of lower quality code in Zzz
    because I'm using LLMs in my workflows
    (and yearning for better tools so building Zzz with haste),
    but the important parts are carefully done, and I still prioritize quality over velocity

## License 🐦

[MIT](LICENSE)
