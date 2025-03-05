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

This is a pre-alpha and the ideas are still developing.
To help see the issues and [discussions](https://github.com/ryanatkn/zzz/discussions)
or find me on [Bluesky](https://bsky.app/profile/ryanatkn.com).

Unlike all of my previous projects, I'm slopping out Zzz's code with generative AI.
I started with several thousand lines of handwritten code in a couple weeks in 2024,
but Claude 3.6 released a week after I started,
and Claude kept delivering results that justified increasing time investment,
and things kept escalating,
and so now today, in this project where I find myself increasingly ~~lazy~~ vibes coding,
Claude gets as much credit as I do for the code, more if you're talking about lines written.
(and **blame**!! this is some of the lowest quality code I've ever published and I need to own that.
I think it's mostly good but there's definitely slop that I'm breezing over in the interest of speed)
You can see the full history of my degeneration from enthusiast coder to slop merchant
in [this PR](https://github.com/ryanatkn/zzz/pull/6).

## Motivation

1. control botz

## Setup

- see [src/lib/server/.env.example](/src/lib/server/.env.example)
  - add to `.env` or `.env.development` and `.env.production` -
    `SECRET_ANTHROPIC_API_KEY`, `SECRET_OPENAI_API_KEY`, `SECRET_GOOGLE_API_KEY`

In your terminal:

```bash
npm run dev
```

Browse to the location is says, probably `localhost:5173`.

## Credits 🐢<sub>🐢</sub><sub><sub>🐢</sub></sub>

Zzz builds on a great deal of software.

- see the deps in [package.json](package.json)
- Claude wrote a lot of code after the initial version, but I try to be meticulous

## License 🐦

[MIT](LICENSE)
