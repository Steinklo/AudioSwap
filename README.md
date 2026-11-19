# AudioSwap 🔊

Sound profiles for **World of Warcraft: Forever**. Save your volume setups and swap between them with one click, or let AudioSwap switch for you.

## ✨ Features

- 🎚️ **Sound profiles** – master, effects, music, ambience and dialog, each with its own on/off toggle
- 👂 **Live preview** – hear your changes while you adjust them
- 🖱️ **One-click switching** – pick a profile from the minimap icon
- 🤖 **Automatic switching** – in combat, in a group, or in a rested area
- 🏆 **You set the priority** – decide which situation wins
- 👥 **Account-wide** – profiles are shared by all your characters

## 🚀 Quick start

1. Type `/audioswap` (or right-click the minimap icon) to open settings.
2. Click **New**, name it (e.g. *Discord* 🎧), and turn the volume down.
3. Left-click the minimap icon and pick it. It stays until you choose **Auto**.
4. Want it hands-free? Pick profiles for **Combat ⚔️**, **Group 👥** or **Rest 🍺** on the right.

## ⌨️ Commands

| Command | What it does |
|---|---|
| `/audioswap` | Open settings |
| `/audioswap <profile>` | Switch to a profile (works in macros) |
| `/audioswap auto` | Back to automatic switching |

## 🛠️ Development

Libraries aren't committed. The packager pulls them in from `.pkgmeta`. For local testing, put LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0 in `Libs/`. Run the logic tests with `lua test_resolve.lua`.

## 📄 License

MIT
