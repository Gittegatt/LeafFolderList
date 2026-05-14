# LeafFolderList

LeafFolderList scans one or multiple directories and lists only **leaf folders** — folders that do not contain any subfolders.

The script supports:
- Multiple scan paths
- Individual recursion depth per path
- Unlimited recursion
- Paths containing spaces
- Clean console output

---

## Features

- Scan multiple directories in a single run
- Per-path depth control
- Unlimited recursion support
- Detects only final/leaf folders
- Simple command-line workflow
- Lightweight PowerShell implementation

---

## Usage

When started, the script prompts for scan paths.

### Input Format

```text
"path"|depth; path2|depth; path3|
```

### Examples

```text
"C:\Media"|2
```

Scan `C:\Media` up to depth 2.

```text
D:\Downloads|
```

Unlimited recursion.

```text
"C:\Movies"|1; D:\Series|3; E:\Music|
```

Multiple scan targets with different depth settings.

---

## Depth Behavior

| Depth | Behavior |
|---|---|
| `0` | Scan only the root folder itself |
| `1` | Scan one level below the root folder |
| empty | Unlimited recursion |

---

## Example Prompt

```text
Separate multiple scan paths with ;
Define depth per path using |
Leave depth empty for unlimited recursion.

Depth 0 = scan only the root folder itself.
Depth 1 = scan one level below the root folder.

Example:
"C:\Path 1"|3; D:\Path2|; E:\Path3|1
```

---

## Output

The script outputs only leaf folders:

```text
C:\Movies\Alien
C:\Movies\Blade Runner
D:\Series\Dark\Season 1
```

---

## Requirements

- Windows PowerShell or PowerShell 7
- Windows operating system

---

## License

MIT License
