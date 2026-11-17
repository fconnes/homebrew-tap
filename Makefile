# The project's single entry point: `make check` before pushing, and the very
# same targets a pre-commit hook and CI invoke wherever the repository has
# them, so "works on my machine" and "passes in CI" mean one thing.
#
# A tap's formulas are read by Homebrew rather than run here, so its gate is
# validation: `brew style` holds each formula to Homebrew's own RuboCop rules
# from the working tree, and Markdown is linted. `audit` reads the formulas
# the way `brew install` does, which Homebrew does only for an installed tap:
# CI runs it on the checkout setup-homebrew taps, and here it runs where this
# clone is that tap. There is no `test`: a formula's `test do` block runs
# where it is installed, by `brew test`.
#
# Targets: help (default), check-lint-tools, lint, fmt, format, audit, check.

# The tap as Homebrew names it: the forge's owner and this repository, the
# `homebrew-` prefix included, which Homebrew strips wherever it reads one.
TAP := fconnes/homebrew-tap

# The tools the gate itself runs. A list of its own, checked only by the
# targets that call them, so a project that later adds a runtime dependency or
# a test runner gives each its own list rather than widening this one.
LINT_TOOLS := markdownlint-cli2 prettier brew
# Prettier lays out the Markdown: it refills each paragraph at 80 columns, so
# an edit that leaves one split is fixed by `make format`. Like the other
# linters it is taken from PATH, CI installing it at a pinned version. Its
# options live in .prettierrc.json5, a copy of the catalog's; the globs are
# this project's own, so a path it leaves alone is a negation here
# (`"!path/**"`), and a passage it must keep as written takes a
# `<!-- prettier-ignore -->` comment above it.
PRETTIER_GLOBS := "**/*.md"

.PHONY: help check-lint-tools lint fmt format audit check

help:
	@printf 'Targets:\n'
	@printf '  make lint     every static check (what a pre-commit hook and CI run)\n'
	@printf '  make fmt      brew style --fix and markdownlint --fix in place (Prettier is make format)\n'
	@printf '  make format   refill the Markdown with Prettier, writing in place\n'
	@printf '  make audit    brew audit and readall over the tap, where this clone is %s\n' '$(TAP)'
	@printf '  make check    lint, the gate to run before pushing\n'

# Report a missing tool with the command that installs it, rather than letting
# the recipe die on a raw "command not found" that names no remedy, and never
# fetch it. Written once and called per list, so the guards cannot drift apart.

# The installer the hint below names. Homebrew where there is one, and
# nothing where there is not: a project that ships to Linux has tools no
# `brew install` can fetch (`gio` is one), and a hint naming a command the
# reader cannot run is the failure the guard exists to prevent, wearing the
# costume of help. Naming the tools alone is honest and still pasteable into
# whatever manager they do have. Override it where the project knows better.
INSTALL_HINT ?= $(if $(filter Darwin,$(shell uname -s)), brew install,)

define check_tools
@missing=''; \
for t in $(1); do \
	command -v "$$t" >/dev/null 2>&1 || missing="$$missing $$t"; \
done; \
[ -z "$$missing" ] || { \
	printf 'missing required tools:%s\n' "$$missing" >&2; \
	printf 'install them first:%s%s\n' '$(INSTALL_HINT)' "$$missing" >&2; \
	exit 1; \
}
endef

check-lint-tools:
	$(call check_tools,$(LINT_TOOLS))

# Every check runs and the recipe exits non-zero if any failed, so one run
# reports the formulas and the Markdown together rather than the first failure.
# `brew style` reads the files themselves, so it checks this working tree
# whether or not the tap is installed, and passes over an empty Formula/.
#
# markdownlint reads .gitignore only when a .markdownlint-cli2.jsonc tells it to
# ("gitignore": true), so without that file the glob below walks into a venv or
# a node_modules and fails on third-party Markdown.
lint: check-lint-tools
	@rc=0; \
	brew style Formula || rc=1; \
	markdownlint-cli2 "**/*.md" || rc=1; \
	prettier --check $(PRETTIER_GLOBS) || rc=1; \
	exit $$rc

# Only the formatters are checked, not the whole lint list: fmt is not the
# gate, and refusing to reformat over a missing linter would be the
# over-checking the separate lists exist to avoid.
fmt:
	$(call check_tools,brew markdownlint-cli2)
	@brew style --fix Formula
	@markdownlint-cli2 --fix "**/*.md"

# Write the Markdown's layout in place, the fix for what `lint`'s Prettier check
# flags: run it after an edit that left a paragraph split. The Markdown's other
# fixes are `fmt`'s.
format:
	$(call check_tools,prettier)
	@prettier --write $(PRETTIER_GLOBS)

# Homebrew audits a formula by its name in an installed tap and refuses a path,
# so this reads the tap Homebrew holds under TAP, and stops where that is not
# this clone: auditing another copy would pass over the edits made here. CI
# meets the condition, setup-homebrew linking the checkout as the tap. `audit
# --strict` adds the checks `brew style` leaves to it, without `--online`,
# which would fetch a private homepage and fail; `readall` loads every formula
# as each system and architecture would, so a formula valid on this Mac and
# broken on Linux fails here rather than on the machine that taps it.
audit:
	$(call check_tools,brew)
	@here=$$(pwd -P); tapdir=$$(brew --repository '$(TAP)'); \
	if [ "$$(cd "$$tapdir" 2>/dev/null && pwd -P)" != "$$here" ]; then \
		printf 'not audited: %s is not this clone\n' "$$tapdir" >&2; \
		printf '  CI runs this audit on every push, its checkout being the tap\n' >&2; \
		exit 1; \
	fi
	@rc=0; \
	brew audit --strict --tap '$(TAP)' || rc=1; \
	brew readall --os=all --arch=all '$(TAP)' || rc=1; \
	exit $$rc

check: lint
