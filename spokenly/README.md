# Spokenly

Reference only — not stowed. Spokenly keeps its settings as JSON blobs inside
`~/Library/Preferences/app.spokenly.plist` (mixed with stats and timestamps), so
there's nothing to symlink. Paste changes in by hand.

## Setup

1. **Settings → AI Processing → Local Models**: add an Ollama-compatible provider
   - Base URL: `http://127.0.0.1:8080/v1`
   - Model: `Qwen3.5-9B`
   - Served by `start-llama-qwen` (see `scripts/`), auto-started by the
     `com.ktjhia.llama-qwen` LaunchAgent.
2. **Default Mode → Prompt**: paste [`cleanup-prompt.md`](cleanup-prompt.md).
3. Other non-default settings: local-only mode on, dictation model Parakeet,
   text typing mode = Smart Paste, auto-copy to clipboard on, hide from Dock.

## Pulling the live prompt back into the repo

```zsh
python3 -c 'import plistlib,json,os
p=plistlib.load(open(os.path.expanduser("~/Library/Preferences/app.spokenly.plist"),"rb"))
m=[i["value"] for i in json.loads(p["modes.v2"])["envelope"]["items"] if i["value"]["name"]=="Default Mode"][0]
print(m["prompt"])' > ~/dotfiles/spokenly/cleanup-prompt.md
```
