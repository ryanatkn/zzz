# Zzz

[<img src="/static/logo.svg" alt="three sleepy z's" align="right" width="192" height="192">](https://www.zzzbot.dev/)

> bot and web toolkit 💤 endgame web UI

⚠️ early pre-release

**[zzzbot.dev](https://www.zzzbot.dev/)**

Zzz, pronounced "zees" like the sound of electricity,
is an open source web UI and toolkit with a focus on AI and user power.

This is a pre-alpha and the ideas are still developing.
To help see the issues and [discussions](https://github.com/ryanatkn/zzz/discussions),
or find me on [Bluesky](https://bsky.app/profile/ryanatkn.com).

More at [zzzbot.dev/about](https://www.zzzbot.dev/about).

## Features

- integrations (everything's a work in progress, but some basics should be working)
  - [Ollama](https://github.com/ollama/ollama)
  - [ChatGPT](https://github.com/openai/openai-node)
  - [Claude](https://github.com/anthropics/anthropic-sdk-typescript)
  - [Gemini](https://github.com/google-gemini/generative-ai-js)
  - more planned, and I welcome feedback/requests/assistance
    - [Model Context Protocol](https://modelcontextprotocol.io/) ([TS lib](https://github.com/modelcontextprotocol/typescript-sdk))

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

## License 🐦

[MIT](LICENSE)
