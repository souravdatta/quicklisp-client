# Installing Quicklisp

## Overview

Clone this repository, then load `quicklisp.lisp` into your Lisp
implementation. The installer copies the client files into
`~/quicklisp/` (or a custom path you specify) and sets everything up.

No files are downloaded during installation. All network access happens
after setup, when Quicklisp fetches the dist index for the first time.
That request is made over HTTPS using `curl`, `wget`, or a custom
downloader you specify via the `FETCHER` environment variable.

---

## Requirements

- A Common Lisp implementation (SBCL, CCL, ABCL, ECL, etc.)
- One of the following for HTTPS downloads:
  - **curl** (recommended on Linux/macOS and available on Windows)
  - **wget** (common on Linux)
  - A custom downloader set via `FETCHER` (see below)

---

## Step 1 — Clone the repository

```bash
git clone https://github.com/quicklisp/quicklisp-client.git
```

---

## Step 2 — Load and install

Start your Lisp implementation, then load `quicklisp.lisp` from the
cloned directory and call `install`.

### SBCL

```bash
sbcl --load /path/to/quicklisp-client/quicklisp.lisp \
     --eval '(quicklisp-quickstart:install)' \
     --quit
```

### CCL

```bash
ccl --load /path/to/quicklisp-client/quicklisp.lisp \
    --eval '(quicklisp-quickstart:install)' \
    --quit
```

### From the REPL (any implementation)

```lisp
(load "/path/to/quicklisp-client/quicklisp.lisp")
(quicklisp-quickstart:install)
```

This installs into `~/quicklisp/` by default.

### Custom install path

```lisp
(quicklisp-quickstart:install :path "/opt/quicklisp/")
```

---

## Step 3 — Add Quicklisp to your Lisp init file

Once installed, run this once inside your Lisp session to have
Quicklisp loaded automatically on every startup:

```lisp
(ql:add-to-init-file)
```

---

## HTTPS downloader selection

After installation, all downloads go through `ql-http:fetch`, which
selects a downloader in this order:

1. **`FETCHER` environment variable** — if set, this program is called
   as `FETCHER <url> <output-file>`
2. **curl** — used if found on `PATH`
3. **wget** — used if found on `PATH`
4. **Error** — if none of the above are available

### Linux / macOS — curl

curl is typically pre-installed on macOS and available via the package
manager on Linux:

```bash
# Debian / Ubuntu
sudo apt install curl

# Fedora / RHEL
sudo dnf install curl

# macOS (pre-installed, or via Homebrew)
brew install curl
```

### Linux — wget

```bash
# Debian / Ubuntu
sudo apt install wget

# Fedora / RHEL
sudo dnf install wget
```

### Windows — curl

curl is bundled with Windows 10 (build 1803) and later and is available
in `cmd.exe` and PowerShell without any installation:

```powershell
curl --version
```

If it is not available, download it from https://curl.se/windows/ and
add it to your `PATH`.

### Windows — custom FETCHER

On Windows you can also point `FETCHER` at PowerShell's
`Invoke-WebRequest` via a small wrapper script, or at any other
download tool:

```bat
REM download.bat
@echo off
powershell -Command "Invoke-WebRequest -Uri '%1' -OutFile '%2'"
```

```bat
set FETCHER=C:\tools\download.bat
sbcl --load C:\path\to\quicklisp-client\quicklisp.lisp ^
     --eval "(quicklisp-quickstart:install)" ^
     --quit
```

---

## Proxy support

Pass `:proxy` to `install` to configure a proxy for the initial dist
fetch:

```lisp
(quicklisp-quickstart:install :proxy "http://proxy.example.com:8080/")
```

Or set it permanently after installation:

```lisp
(setf ql:*proxy-url* "http://proxy.example.com:8080/")
```

---

## Updating

To update the installed client from a newer clone of this repo, simply
delete `~/quicklisp/` and run `install` again, or call:

```lisp
(ql:update-client)
```
