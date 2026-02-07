# CLI Specification

How will we interact with the program?

## Overview

Keep it simple stupid!! Unix is king, and we live by their philosophy.

Ralph has two subcommands: `build` and `plan`. If you don't specify one, it defaults to `build`.

```sh
# Build mode (default) -- implement from the plan
ralph build "focus on the auth module" \
  --model=opus-4.5 \
  --max-iterations=10 \
  --duration=10 \
  --max-context=80000 \
  --completion="<promise>COMPLETE</promise>"

# Plan mode -- gap analysis, update plans, no implementation
ralph plan "user authentication system"

# Default is build, so these are equivalent:
ralph --max-iterations=10
ralph build --max-iterations=10

# Stdin still works as it always has
cat my-prompt-file.md | ralph build --model=opus-4.5
cat my-goals.md | ralph plan
```

The subcommand selects the prompt template (`Prompt::Build` or `Prompt::Plan`). Any additional text from stdin or positional arguments is appended as user context within the prompt.

## Options

All options work with both subcommands:

- `--model=MODEL` -- model to use
- `--max-iterations=N` -- maximum number of iterations
- `--duration=SECONDS` -- maximum total duration in seconds
- `--max-context=N` -- maximum context tokens before iteration restart
- `--completion=STRING` -- completion string the agent emits when done
- `-h, --help` -- show help
- `-v, --version` -- show version
