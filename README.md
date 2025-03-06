# Zzz

[<img src="/static/logo.svg" alt="three sleepy z's" align="right" width="192" height="192">](https://www.zzzbot.dev/)

> bot and web toolkit 💤 bot control web

⚠️ early pre-release

**[zzzbot.dev](https://www.zzzbot.dev/)**

Zzz, pronounced "zees" like the sound of electricity,
is a bot and web toolkit with a focus on user power and experimentation.
The idea is to make a digital tool that adapts to your needs on the fly
while remaining fully in your control and open source.
More at [zzzbot.dev/about](https://www.zzzbot.dev/about).

This is a pre-alpha and the ideas are still developing -
see the issues and [discussions](https://github.com/ryanatkn/zzz/discussions)
or find me on [Bluesky](https://bsky.app/profile/ryanatkn.com).

Unlike all of my previous projects, I'm slopping out Zzz's code with generative AI.
I started with several thousand handwritten lines over a couple weeks in October 2024,
after naming the project that January and thinking about it a lot.
A week later Claude 3.6 was released - I had been using 3.5 with enthusiasm
but this model gave me a series of "oh.." moments that filled me with excitement and dread.

Things kept escalating to where I find myself increasingly ~~lazy~~ vibecoding.
Claude gets as much credit as I do for the code, more if you're talking about lines written.
(and none of the **blame**!?)
This is some of the lowest quality code I've ever published and I need to own that.
I think it's mostly good, much better than the statistical average,
but there's definitely slop in less important parts of the code
that I'm breezing through in the interest of speed and priorities.
You can see my degeneration from enthusiast coder to slop merchant
in [PR #6](https://github.com/ryanatkn/zzz/pull/6).

## Motivation

1. control botz

## Setup

Zzz uses SvelteKit and Vite and currently requires Node.
(or at least, that's the only one I've tested)
The goal is to make it support many deployment targets and all the JS runtimes,
including a desktop installation and npm library,
but it's not there yet - for now you'll need Node 20.17+ and git to clone the repo.

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

## Credits 🐢<sub>🐢</sub><sub><sub>🐢</sub></sub>

Zzz builds on a great deal of software.

- see the deps in [package.json](package.json)
- [Claude](https://claude.ai/) wrote a lot of code after the initial version
  and is the main writer these days

## License 🐦

[MIT](LICENSE)
