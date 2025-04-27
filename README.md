# Zzz

[<img src="/static/logo.svg" alt="three sleepy z's" align="right" width="192" height="192">](https://www.zzz.software/)

> web environment 💤 nice web things for the tired

⚠️ early pre-release

**[zzz.software](https://www.zzz.software/)**

Zzz, pronounced "zees" like bees,
is a software project with a focus on user power and experimentation.
The idea is to make fullstack software that adapts to your needs on the fly
while remaining fully open, aligned, and in your control.

This is a pre-alpha and the ideas are still developing -
see the issues and [discussions](https://github.com/ryanatkn/zzz/discussions)
or @ me on [Bluesky](https://bsky.app/profile/ryanatkn.com).

More at [zzz.software/about](https://www.zzz.software/about).

## Setup

Zzz uses SvelteKit and Vite and currently requires Node.
(Node is the only runtime I've tested, YMMV with Deno/Bun/etc)
Eventually there will be an installable desktop app and npm library,
but it's not there yet - for now you'll need `node` 22.11+ and `git` to clone the repo.

It can be deployed via SvelteKit's static adapter with diminished capabilities.

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
- input welcome

## Credits 🐢<sub>🐢</sub><sub><sub>🐢</sub></sub>

Zzz builds on a great deal of software.

- see the deps in [package.json](package.json)
- [Claude](https://claude.ai/) wrote a lot of code after the initial version
  and is the main writer these days

## License 🐦

[MIT](LICENSE)
