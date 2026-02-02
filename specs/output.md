# Output Specification

All terminal output in Ralph is structured as callable output classes under the `Ralph::Output` namespace. Each class encapsulates a single output concern — a banner, a warning, a summary — and exposes a `self.call` class method as its only public interface.

## Namespace & File Layout

```
lib/ralph/output/
  no_plugin_warning.rb    # Ralph::Output::NoPluginWarning
  banner.rb               # Ralph::Output::Banner
  iteration.rb            # Ralph::Output::Iteration::Header
                          # Ralph::Output::Iteration::Summary
                          # Ralph::Output::Iteration::Error
  ...
```

Each file defines one or more classes inside `module Ralph; module Output; ... end; end`.

When several output classes share a common concern (e.g. iteration lifecycle), they are grouped under a nested module in a single file. The submodule acts as a namespace — it contains only classes, no logic of its own.

## Interface: The Callable Object Pattern

Every output class follows the same shape:

```ruby
module Ralph
  module Output
    class ExampleWarning
      def self.call(thing:, count:)
        warn "Warning: #{thing} happened #{count} times"
      end
    end
  end
end
```

### Rules

| Rule | Detail |
|------|--------|
| **Entry point** | `self.call` — a class method, never instantiated |
| **Arguments** | All inputs passed as **keyword arguments** for clarity at the call site |
| **Return value** | None expected. These are fire-and-forget side-effect methods |
| **Single responsibility** | One output concern per class. If a method prints a banner, that's one class. If it prints an iteration summary, that's another |
| **Grouping** | Related output classes may be grouped under a nested module in a single file (e.g. `Output::Iteration::Header`, `Output::Iteration::Summary`, `Output::Iteration::Error` all live in `iteration.rb`) |
| **No base class** | Plain `Object` inheritance. No shared superclass or included module required |

## Output Channels

Use the appropriate channel based on the nature of the output:

| Channel | Ruby method | When to use |
|---------|-------------|-------------|
| **stdout** | `puts` | Informational output: banners, summaries, progress, status |
| **stderr** | `warn` or `$stderr.puts` | Warnings, errors, and diagnostics that should not pollute stdout |

`warn` is preferred over `$stderr.puts` for single-line warnings because it respects Ruby's `-W` flag and is idiomatic.

## Requiring & Usage

Output classes are required where they are used, not auto-loaded:

```ruby
require_relative "output/no_plugin_warning"

# Later, at the call site:
Output::NoPluginWarning.call(agent_type: @agent_config.type)
```

There is no `lib/ralph/output.rb` barrel file. Each class is required individually by the code that needs it.

## Reference Implementation

`lib/ralph/output/no_plugin_warning.rb` is the canonical example:

```ruby
module Ralph
  module Output
    class NoPluginWarning
      def self.call(agent_type:)
        case agent_type
        when :claude_code
          warn "Warning: --no-plugins has no effect with Claude Code agent"
        when :codex
          warn "Warning: --no-plugins has no effect with Codex agent"
        end
      end
    end
  end
end
```

Key things to note:

- The class decides **what** to print based on its arguments (the `case` on `agent_type`).
- The caller does not need to know the message text — it passes data, and the output class formats it.
- The caller (`Loop#call` in `lib/ralph/loop.rb`) reads as `Output::NoPluginWarning.call(agent_type: ...)` — intent is clear at the call site.

## Formatting Conventions

- **Box-drawing characters** (`═`, `║`, `╔`, `╗`, `╚`, `╝`, `─`) are used for prominent banners and completion boxes.
- **Unicode symbols** (checkmarks, warning signs, emoji) are used sparingly for status indicators.
- **Line width** is 68 characters for horizontal rules and box borders.
- Formatting logic lives inside the output class, not at the call site.
