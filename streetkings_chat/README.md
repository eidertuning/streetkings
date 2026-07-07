# StreetKings Chat

Standalone freeroam chat for the StreetKings framework.

## Install

Add it after `streetkings` in `server.cfg`:

```cfg
ensure streetkings
ensure streetkings_chat
```

## Usage

- `T`: open chat.
- Plain text: global freeroam message.
- `/mp id message`: private message.

The server also checks StreetKings game state, so chat only works in `freeroam`.
