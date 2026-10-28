<p align="center">
  <img src="docs/logo.png" width="128" alt="Copiest logo: a clipboard with lines of text">
</p>

# Copiest

Copiest is a clipboard history app for the macOS menu bar. It remembers the text that you
copy, so you can find an earlier item and paste it again. To open your history from any
app, press Command-Shift-V. Copiest also keeps passwords, API keys, and other secrets
out of the history.

## Features

- **Search your clipboard history.** Find any of your last 500 copied items by its text
  or by the app that you copied it from.
- **Work from the keyboard.** Open the history, search, choose an item, and paste it
  without touching the mouse.
- **Pin the items that you reuse.** Pinned items stay at the top of the list and never
  leave the history.
- **Keep secrets out.** Copiest skips passwords from password managers, everything
  that you copy in apps that you choose, and text that looks like a credential, such as
  an API key or a database URL with a password.
- **Pause recording.** Stop recording with a keyboard shortcut of your choice before
  you work with sensitive text.
- **Stay private.** The history stays on your Mac, in a file that only your user account
  can read. Copiest makes no network connections.

## Requirements

Copiest requires macOS 14 or later.

## Install Copiest

You can install Copiest with Homebrew or download it from GitHub.

### Install with Homebrew

1. If you don't have Homebrew, install it from [the Homebrew website](https://brew.sh).
2. To install Copiest from the CraftAtom tap, run this command:

   ```sh
   brew install --cask craftatom/tap/copiest
   ```

3. Open **Copiest** from the `Applications` folder. The Copiest icon appears in the menu
   bar.

To update Copiest, run `brew upgrade --cask copiest`. To remove Copiest, run
`brew uninstall --cask copiest`. To also delete your clipboard history and settings, run
`brew uninstall --cask --zap copiest`.

### Download from GitHub

1. Download `Copiest.zip` from the
   [latest release](https://github.com/CraftAtom/copiest/releases/latest).
2. Open the downloaded file. macOS unzips it to `Copiest.app`.
3. Move `Copiest.app` to your `Applications` folder.
4. Open **Copiest** from the `Applications` folder. The Copiest icon appears in the menu
   bar.
5. Optional: To start Copiest when you log in, right-click the menu bar icon and click
   **Launch at Login**.

Apple notarizes every release, so macOS opens Copiest without a security warning.

To update Copiest, download the latest release and replace the app in your
`Applications` folder. Copiest keeps your history and settings.

### Install from source

To build Copiest yourself, you need the Xcode command line tools. To install them, run
`xcode-select --install`.

1. Clone the repository:

   ```sh
   git clone https://github.com/CraftAtom/copiest.git
   cd copiest
   ```

2. To build the app and copy it to `/Applications`, run the build script with the
   `--install` flag:

   ```sh
   ./build.sh --install
   ```

3. Open **Copiest** from `/Applications`. The Copiest icon appears in the menu bar.
4. Optional: To start Copiest when you log in, right-click the menu bar icon and click
   **Launch at Login**.

To update Copiest later, run `git pull` in the repository folder, and then run
`./build.sh --install` again.

## Use Copiest

To open your clipboard history, press Command-Shift-V or click the menu bar icon. If the
icon is hidden, for example behind the camera housing, open Copiest from Spotlight.

When the window opens, your most recent copy is selected. The app that you were in stays
active, so after you choose an item, you can press Command-V to paste it there.

| To do this | Press |
| --- | --- |
| Open or close the history | Command-Shift-V |
| Search | Start typing |
| Move through the list | Up Arrow or Down Arrow |
| Copy the selected item | Return, or double-click the row |
| Pin or unpin the selected item | Command-P |
| Delete the selected item | Command-Delete |
| Close the window | Escape, or click another app |

You can also right-click a row to copy, pin, or delete it. To remove every item that
isn't pinned, right-click the menu bar icon and click **Clear History**.

Copiest records plain text up to 100 KB for each item. When you copy text that is
already in the history, Copiest moves the existing item to the top.

If another app already uses Command-Shift-V, the menu bar menu says so. In that case,
open Copiest from the menu bar icon.

## Keep secrets out of the history

Copiest skips these items, so they never reach the history:

- Items that apps mark as private through the
  [NSPasteboard.org conventions](http://nspasteboard.org), such as passwords that you copy
  from 1Password and other password managers.
- Everything that you copy in an ignored app, including a copy that you make right
  before you switch to another app. By default, the list includes Keychain Access,
  Passwords, 1Password, Bitwarden, KeePassXC, and LastPass.
- Text that looks like a credential:
  - Access tokens and API keys from services such as GitHub, GitLab, OpenAI, Anthropic,
    Stripe, Amazon Web Services (AWS), Slack, Google, SendGrid, Hugging Face,
    DigitalOcean, Shopify, npm, and the Python Package Index (PyPI).
  - Private keys, JSON Web Tokens (JWTs), and `Authorization: Bearer` headers.
  - Passwords inside URLs, such as `postgres://user:password@host`.
  - Password, secret, token, and key settings in `.env`, JSON, and YAML files, such as
    `export API_TOKEN=…` or `"db_password": "…"`.
  - Command-line flags such as `--password=…` and `--api-key …`.

Copiest can't recognize every secret. A secret in another format is still recorded. To
remove an item, select it and press Command-Delete. To skip copies on purpose, pause
recording.

### Pause recording

To pause recording, right-click the menu bar icon and click **Pause Recording**. While
recording is paused, the menu bar icon is dimmed, and the history window shows when
recording resumes. To resume, click **Resume Recording** in the same menu.

To pause and resume with a keyboard shortcut, follow these steps:

1. Right-click the menu bar icon and click **Settings**.
2. Click **Record Shortcut**, and then press a key with Command, Control, or Option.
3. In the **Resume recording** list, choose when recording resumes on its own:
   - **After the Next Copy**: Copiest skips one copy, and then records again.
   - **After 1 Minute**, **After 5 Minutes**, or **After 15 Minutes**.
   - **When I Resume**: Copiest records again only when you press the shortcut again.

### Change the ignored apps and the secret filter

1. Right-click the menu bar icon and click **Settings**, or click the gear button in the
   history window.
2. To add an app to the ignored apps, click **Add App**, and then choose the app. To
   remove an app, click the minus button next to it.
3. To turn the secret filter on or off, click **Skip text that looks like a password or
   API key**.

## Where Copiest stores your history

Copiest stores the history in `~/Library/Application Support/Copiest/history.json`. Only
your user account can read the file. The history never leaves your Mac.

If Copiest can't read the file, it keeps the file as `history-unreadable-<number>.json`
in the same folder and starts a new history.

To delete the whole history, including pinned items, quit Copiest and delete the
`~/Library/Application Support/Copiest` folder.

## Build from source

Copiest is a Swift package with no dependencies outside the macOS software development
kit (SDK). It doesn't use an Xcode project.

| Path | Contents |
| --- | --- |
| `Sources/Copiest/App.swift` | App delegate, menu bar item, and history window |
| `Sources/Copiest/History.swift` | Clipboard monitoring and the history file |
| `Sources/Copiest/SecretFilter.swift` | Patterns that recognize credentials |
| `Sources/Copiest/Settings.swift` | Settings window and the shortcut recorder |
| `Sources/Copiest/Preferences.swift` | Saved settings and shortcut definitions |
| `Sources/Copiest/HotKey.swift` | Global keyboard shortcuts |
| `scripts/make-icon.swift` | Drawing code for the app icon and logo |

### Build the app

To build `build/Copiest.app` without installing it, run the build script:

```sh
./build.sh
```

The script compiles a release build with `swift build`, assembles the app bundle, and
signs it with an ad hoc signature. To open the app that you built, run
`open build/Copiest.app`.

### Sign and notarize the app

An app with an ad hoc signature runs only on the Mac that built it. To share Copiest with
other Macs, sign it with a Developer ID certificate and have Apple notarize it. You need
a membership in the Apple Developer Program.

1. To find the name of your signing identity, run this command:

   ```sh
   security find-identity -v -p codesigning
   ```

   Use the identity that starts with `Developer ID Application`.

2. To save your notary credentials in the keychain, run this command. Replace the
   placeholders with your Apple Account email address, your team ID, and a profile name
   that you choose. The command asks for an app-specific password, which you can create
   at [Apple Account](https://account.apple.com).

   ```sh
   xcrun notarytool store-credentials PROFILE_NAME \
       --apple-id APPLE_ACCOUNT_EMAIL --team-id TEAM_ID
   ```

3. To build, sign, notarize, and staple the app, run the build script with the
   `--notarize` flag:

   ```sh
   CODESIGN_IDENTITY="Developer ID Application: NAME (TEAM_ID)" \
   NOTARY_PROFILE=PROFILE_NAME ./build.sh --notarize
   ```

   The script writes the notarized app to `build/Copiest.app` and a ZIP archive to share
   to `build/Copiest.zip`.

The signature shows your certificate name and team ID to anyone who has the app. The
build script reads your identity from environment variables, so it never enters the
repository.

### Test the secret filter

To check the secret filter against sample secrets and ordinary text, run the binary with
`--selftest`. The command prints `selftest ok`, or prints the failing sample and exits
with a nonzero status.

```sh
build/Copiest.app/Contents/MacOS/Copiest --selftest
```

When you add a pattern to `SecretFilter.swift`, add a sample secret to
`selftestSecrets` and a similar text that must still be recorded to `selftestKeep`.

### Regenerate the icon

To regenerate `Resources/AppIcon.icns` and `docs/logo.png` after you change the drawing
code in `scripts/make-icon.swift`, run the script:

```sh
swift scripts/make-icon.swift
```

## License

Copiest is available under the MIT License. For details, see [the license file](LICENSE).
