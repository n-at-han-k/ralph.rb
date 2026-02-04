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
| [cli.md](./cli.md) | [exe/ralph](../exe/ralph) | Command-line interface specification for interacting with ralph |
| [loop.md](./loop.md) | — | Core loop architecture and iteration management |
| [agents.md](./agents.md) | — | Integration with opencode agents and JSON streaming |
| [metrics.md](./metrics.md) | — | Context and token usage calculation from JSON streams |
