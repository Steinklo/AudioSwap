# AudioSwap

Sound profiles for World of Warcraft: Forever. Switch them by hand or let them switch automatically.

## Use

- **Minimap icon**: left-click to pick a profile or **Auto**, right-click for settings.
- **`/audioswap`** opens settings. **`/audioswap <profile>`** picks a profile, **`/audioswap auto`** resumes automatic switching (works in macros).
- A profile picked by hand stays until you choose **Auto**.

## Automatic switching

Map situations to profiles in *Options → AddOns → AudioSwap*:

| Situation | When |
|---|---|
| Combat | In combat |
| Group | In any party or raid (dungeons and battlegrounds too) |
| Rest | In a rested area (cities, inns) |

Situations are ranked (default Combat > Group > Rest); the highest one that applies and has a profile wins. Nothing applies → the Default profile. Sound profiles are shared by all your characters.

## Development

Libraries aren't committed. The packager fetches them from `.pkgmeta`; for local testing put LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0 under `Libs/`.
