# homebrew-tap

[![CI](https://github.com/fconnes/homebrew-tap/actions/workflows/ci.yml/badge.svg)](https://github.com/fconnes/homebrew-tap/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The public Homebrew tap of the published tools of Frédéric Connes.

## Using it

Tap it once on each machine, in a terminal:

```bash
brew tap fconnes/tap
```

Then install a tool by its name, and `brew upgrade` brings it to the version its
formula names:

```bash
brew install <formula>
```

## Formulas

| Formula     | Tool                         |
| ----------- | ---------------------------- |
| `<formula>` | What the tool does, one line |

## Writing a formula

Each formula is `Formula/<name>.rb`, building its tool from a tagged revision of
the tool's own repository. A public repository is downloaded as the archive of
its tag, checked by its hash:

```ruby
url "https://github.com/fconnes/<tool>/archive/refs/tags/v1.0.0.tar.gz"
sha256 "<the archive's sha256>"
```

A private one has no archive a token can open on github.com, a fine-grained
token getting a 404 there, so its own repository's release workflow attaches an
asset to the version's release (the tag's `git archive` for a tool of scripts,
the binary it builds on a macOS runner for a compiled tool), and the formula
downloads it through GitHub's API, which serves it to that token:

```ruby
url "https://api.github.com/repos/fconnes/<tool>/releases/assets/<asset id>",
    headers: [
      "Accept: application/octet-stream",
      "Authorization: Bearer #{ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "")}",
    ]
version "1.0.0"
sha256 "<the asset's sha256>"
```

The asset's id and hash are read with
`gh api repos/fconnes/<tool>/releases/tags/v1.0.0 --jq '.assets[] | [.id, .digest]'`.
A source cloned through git (`using: :git`) fails in that sandbox, which also
sets `GIT_ASKPASS=/usr/bin/false`.

**A private tool under another owner** is out of the token's reach, a
fine-grained token reading one owner alone, and a second token never reaches its
asset: Homebrew sends a formula's other variables only with redirects forbidden,
and GitHub serves an asset through a redirect. So its asset is copied, byte for
byte, into a release of this tap tagged `<tool>-<version>`, and the formula
downloads that copy, its `sha256` the original's:

```sh
gh release download v1.0.0 --repo <owner>/<tool> --pattern '<asset>' --dir <directory>
gh release create <tool>-1.0.0 --repo fconnes/homebrew-tap --target main <directory>/<asset>
```

The previous version's copy is deleted once the new one is installed. A tool
that moves to another tap leaves a `tap_migrations.json` here naming it, which
`brew upgrade` follows only to a tap the machine already taps and trusts: a
machine that has not gets the commands to run and keeps the old version, so the
new tap is trusted on each machine before the move.

What `install` runs follows the tool's language, as Homebrew's own formulas
write it ([Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)):

- **Rust**: a private tool ships the binary its release workflow builds, so no
  machine compiles it: `depends_on arch: :arm64` where every machine is Apple
  Silicon, then `bin.install "<tool>"`. A public one may build from source
  instead: `depends_on "rust" => :build`, then
  `system "cargo", "install", *std_cargo_args`.
- **Python**: `depends_on "python@3.x"`, `include Language::Python::Virtualenv`
  in the class and a `resource` per dependency, then
  `virtualenv_install_with_resources`.
- **Swift**: built with the Mac's Xcode toolchain,
  `system "swift", "build", *std_swift_args`, then `bin.install` the binary
  under `.build/release/`.
- **Shell**: `bin.install "bin/<tool>"`, with a `depends_on` for every command
  the script calls that macOS does not ship.

Every formula carries a `test do` block exercising the installed tool, at least
its `--version`, which `brew test <formula>` runs where it is installed.

## Publishing a version

Tag the version in the tool's repository, then update its formula here: the
archive's URL and `sha256` for a public tool, the asset's id in the URL, the
`version` and the `sha256` for a private one, after copying the asset into this
tap's releases for a tool under another owner. Once it is pushed, upgrade the
tool on a machine that taps it and run its test there:

```bash
brew upgrade <formula> && brew test <formula>
```

**Renaming a formula** goes through `formula_renames.json`. While a machine's
copy of the tap holds that file, the old name is an alias of the new one:
`brew list` shows both and `brew uninstall <old>` removes the new formula's keg
(seen 2026-11-06). Uninstall nothing after a rename; the alias goes once the
file is dropped from the tap and the machine runs `brew update`.

## Development

```sh
make check    # lint, the gate to run before pushing
```

`make lint` runs `brew style` over `Formula/`, then markdownlint and Prettier
over this file and every other Markdown here; `make fmt` applies the fixes
`brew style` knows, and `make format` refills a paragraph left split at 80
columns. `make audit` runs `brew audit --strict` and `brew readall` over the
tap, which Homebrew does only for an installed one: CI runs it on every push,
the checkout being the tap, and locally it refuses unless the tap Homebrew holds
is this clone.

## License

MIT. See [LICENSE](LICENSE).
