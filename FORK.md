# What's different in this fork

[RascalTwo](https://github.com/RascalTwo)'s fork of [herdrdev/herdr](https://github.com/herdrdev/herdr),
branch `rascaltwo`, kept as a small stack of commits on top of an upstream release tag
(`git log v0.9.3..HEAD` is always exactly the delta).

Nothing here is going upstream. herdr closes unsolicited implementation pull requests from anyone
not on its approved-contributor list (`CONTRIBUTING.md`), and the request for the first change below
([discussion #2047](https://github.com/herdrdev/herdr/discussions/2047), 3 upvotes, no maintainer
reply) is a feature request, which belongs in Discussions. So this is a fork, carried until upstream
makes these configurable itself — then delete the matching patch.

| | Upstream | Here |
| --- | --- | --- |
| `[ui.sidebar.agents] separator` | hardcoded `" · "` between tokens | **configurable**, default `" · "` |
| `[ui.sidebar.agents] indent` | hardcoded `1` (first row) | **configurable**, default `1` |
| `[ui.sidebar.agents] continuation_indent` | hardcoded `3` (later rows) | **configurable**, default `3` |
| `herdr update` / update notices | on | **off** — a stock download would replace this build |

Defaults reproduce stock behaviour exactly, so an unconfigured fork looks like upstream.

## Patch: sidebar separator and indents

```toml
[ui.sidebar.agents]
separator = " "              # text between adjacent tokens; "" for none
indent = 0                   # leading spaces on the first row
continuation_indent = 0      # leading spaces on the 2nd+ rows
```

- A `state_icon` is still always followed by a single space, whatever `separator` is.
- Control characters in `separator` are dropped (they would corrupt the terminal).
- Agent rows only. The Spaces sidebar still uses `" · "`: nobody needed it, and every extra
  call site is another conflict on the next rebase.
- Why: separately coloured tokens each need to be their own token, and herdr joined them with a dim
  ` · ` the config could not touch — see `tools/statusline` in the ai-setup repo, which pushes
  per-pane tokens (`ctx_*`, `cache_*`) into a second row.

Files: `src/config/sidebar.rs` (the three keys), `src/ui/sidebar/tokens.rs` (`separator()` takes the
string), `src/ui/sidebar.rs` (`resolved_token_spans` takes it), `src/client/shell/agent_sidebar.rs`
(passes the config and both indents), `src/client/shell/sidebar.rs` (Spaces passes the default),
`src/config.rs` (re-export), plus `src/main.rs` template and
`docs/next/website/src/data/config-reference.json` so `scripts/config_reference_check.py` stays green.
The config rides in the already-cloned `agents` struct, so client reload needed no changes.

## Updates are off, deliberately

`herdr update` downloads the stock release and renames it over the running binary; the background
check announces upstream releases as if they were updates. Both are gated by one constant,
`UPDATES_ENABLED = false` in `src/update.rs`, and `updates_are_off_in_this_fork` pins it so a rebase
cannot quietly restore it. Update with `scripts/update-from-upstream.sh` instead. (The agent-detection
manifest updater is separate and left on.)

## Building

- **Zig 0.16.0** (`brew install zig`) — the vendored `libghostty-vt` is built with it. Without it the
  build stops in `crates/ghostty-vt/build.rs`.
- **Rust 1.96.1** — pinned by `rust-toolchain.toml`; rustup fetches it.
- `cargo build --release --locked` — about 2 minutes warm. Binary: `target/release/herdr`.
- Tests: **`cargo nextest run --locked`** (`brew install cargo-nextest`). Plain `cargo test` dies
  with a SIGPIPE partway through; the repo's own `just test` uses nextest.

## Keeping up with upstream

```sh
scripts/update-from-upstream.sh          # onto the newest upstream tag
scripts/update-from-upstream.sh v0.9.4   # or a specific one
git push --force-with-lease              # yours to make; the script never pushes
```

Rebase on release tags, not `master`. The script prints which files both sides touched, takes a
`backup/pre-<tag>-<time>` branch, rebases, then runs the full test suite and a release build.

Where conflicts will come from — sidebar token code changed in 0.9.0 and 0.9.1:

- `src/ui/sidebar.rs`, `src/ui/sidebar/tokens.rs`, `src/client/shell/agent_sidebar.rs` — upstream
  adds sidebar features here. If a new caller of `resolved_token_spans` appears, it needs the extra
  `between` argument (the compiler will say so).
- `src/update.rs` — the two guards at the top of `self_update` and `auto_update`.
- `docs/next/website/src/data/config-reference.json` and `docs/next/CHANGELOG.md` — regenerated
  per release; keep both of our entries.
- `Cargo.lock` — take upstream's wholesale and rebuild.

If upstream ships a real configurable separator or indent, drop the patch and map our keys onto
theirs.
