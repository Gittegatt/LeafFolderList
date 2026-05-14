![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
[![Ko-Fi](https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/gittegatt)

# LeafFolderList

LeafFolderList scans one or multiple directories and lists only **leaf folders** — folders that do not contain any subfolders.

Useful for analyzing generic folder structures such as exports, archives, document collections, Excel file directories, text file repositories, or project folders.

---

# Features

- Scan multiple directories in one run
- Individual recursion depth per path
- Unlimited recursion support
- Supports paths with spaces
- Outputs only leaf folders
- Lightweight PowerShell implementation
- Simple interactive workflow

---

# Usage

When the script starts, you will be prompted to enter one or multiple scan paths.

## Input Format

```text
"path"|depth; path2|depth; path3|
```

---

# Examples

## Limited recursion

```text
"C:\Exports"|2
```

Scans up to 2 levels below the root folder.

---

## Unlimited recursion

```text
D:\TextFiles|
```

Scans all subfolders recursively.

---

## Multiple paths

```text
"C:\Excel Files"|1; D:\Reports|3; E:\Archive|
```

Scans multiple directories with different depth settings.

---

# Depth Behavior

| Depth | Behavior |
|---|---|
| `0` | Scan only the root folder itself |
| `1` | Scan one level below the root folder |
| `2` | Scan two levels below the root folder |
| `...` | Continue increasing recursion depth accordingly |
| empty | Unlimited recursion |

---

# Example Prompt

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

# Example Output

```text
C:\Exports\January
C:\Exports\February
C:\Excel Files\Reports
D:\TextFiles\Archive
```

---

# Requirements

- Windows PowerShell 5.1 or newer
- PowerShell 7 recommended
- Windows operating system

---

# License

MIT License
