# homebrew-tap

[![CI](https://github.com/fconnes/homebrew-tap/actions/workflows/ci.yml/badge.svg)](https://github.com/fconnes/homebrew-tap/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The public Homebrew tap of the published tools of Frédéric Connes.

## Using it

Tap it once on each machine, in a terminal:

```bash
brew tap fconnes/tap
```

Homebrew refuses a formula from a tap it was not told to trust, so trust it once
on each machine:

```bash
brew trust fconnes/tap
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

## License

MIT. See [LICENSE](LICENSE).
