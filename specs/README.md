<!--
 Copyright (c) 2025 Nathan Kidd <nathankidd@hey.com>. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

<!--
  HOW TO MAINTAIN THIS FILE

  This is the index of all design specifications for Ralph.rb.
  Each row links a spec document to its implementation code and a short purpose summary.

  When adding a new spec:
  1. Create the markdown file in this directory (specs/)
  2. Add a row to the appropriate table section below
  3. Link the spec file, the code path it describes, and a brief purpose

  Table format:
    | [spec-name.md](./spec-name.md) | [path/to/code](../path/to/code) | Short description |

  Use "—" in the Code column if the spec has no implementation yet.
  Group specs under heading sections by domain area.
-->

# Ralph.rb Specifications

Design documentation for Ralph.rb, a Ruby CLI that runs iterative AI development loops.

## Core

| Spec | Code | Purpose |
|------|------|---------|
| [cli.md](./cli.md) | [lib/ralph/cli.rb](../lib/ralph/cli.rb) | CLI options, subcommands, prompt resolution, error handling |
| [storage/local-data-structure.md](./storage/local-data-structure.md) | [lib/ralph/storage/](../lib/ralph/storage/) | Ralph state persistence: .ralph/ directory, storage module architecture, data lifecycle |

## Output

| Spec | Code | Purpose |
|------|------|---------|
| [output.md](./output.md) | [lib/ralph/output/](../lib/ralph/output/) | Terminal output structure: callable object pattern, channels, formatting conventions |
