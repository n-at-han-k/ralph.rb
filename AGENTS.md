# Ralph.rb Agent Guidelines

## Specifications

**IMPORTANT:** Before implementing any feature, consult the specifications in `specs/README.md`.

- **Assume NOT implemented.** Many specs describe planned features that may not yet exist in the codebase.
- **Check the codebase first.** Before concluding something is or isn't implemented, search the actual code. Specs describe intent; code describes reality.
- **Use specs as guidance.** When implementing a feature, follow the design patterns, types, and architecture defined in the relevant spec.
- **Spec index:** `specs/README.md` lists all specifications organized by category (core, LLM, security, etc.).

## Testing

The `bin/` directory contains scripts for verifying code quality:

- **`bin/test`** -- runs the test suite.
- **`bin/rubocop`** -- runs the RuboCop linter and style checks.

Run both before submitting changes to ensure tests pass and code style is consistent.

## Ruby Style

### No early returns. No guard clauses.

Methods must not use `return` to bail out early. Guard clauses (`return unless`, `return if`) create flat-looking code that hides the actual control flow. Instead, use explicit `if`/`unless` blocks. **Indentation is what creates readability** -- it visually communicates the nesting of conditions and the scope of logic.

**Bad -- guard clauses:**
```ruby
def process(data)
  return unless data
  return if data.empty?
  return unless valid?(data)

  do_work(data)
end
```

**Good -- explicit conditionals:**
```ruby
def process(data)
  if data && data.any? && valid?(data)
    do_work(data)
  end
end
```

### Use `.then` and `.tap` for pipelines

`.then` (aliased `yield_self`) and `.tap` are preferred for expressing data flow. They make the chain of operations explicit and avoid throwaway local variables.

- **`.then`** -- transforms a value and passes the result forward.
- **`.tap`** -- performs a side effect and returns the original value unchanged.

**Bad -- intermediate variables and guard returns:**
```ruby
def maybe_print_tool_summary(force: false)
  return unless @compact_tools
  return if @stream_tool_counts.empty?

  now = now_ms
  return if !force && (now - @last_tool_summary_at < @tool_summary_interval_ms)

  summary = format_tool_summary(@stream_tool_counts)
  return if summary.empty?

  puts "| Tools    #{summary}"
  @last_printed_at = now_ms
  @last_tool_summary_at = now_ms
end
```

**Good -- conditionals with `.then`:**
```ruby
def maybe_print_tool_summary(force: false)
  if @compact_tools && @stream_tool_counts.any?
    now = now_ms
    if force || (now - @last_tool_summary_at >= @tool_summary_interval_ms)
      format_tool_summary(@stream_tool_counts).then do |summary|
        unless summary.empty?
          puts "| Tools    #{summary}"
          @last_printed_at = now_ms
          @last_tool_summary_at = now_ms
        end
      end
    end
  end
end
```

### No abbreviated variable names

Variable names must never be shortened or abbreviated. Always use the full, descriptive name. Abbreviated names save a few keystrokes but cost readability every single time someone reads the code.

**Bad -- abbreviated names:**
```ruby
si = @struggle_indicators
cfg = load_config
msg = build_message(u)
```

**Good -- full names:**
```ruby
struggle_indicators = @struggle_indicators
config = load_config
message = build_message(user)
```

### Why this matters

- **Indentation reveals structure.** You can scan the left margin and immediately understand the conditional depth. Guard clauses flatten everything to the same level, making it impossible to see which conditions gate which logic.
- **Methods have one exit point.** The method body is a single expression tree. No surprises, no hidden bail-outs mid-function.
- **`.then` makes data flow explicit.** Instead of `x = compute(); use(x)`, you write `compute.then { |x| use(x) }`. The pipeline reads top-to-bottom, cause-to-effect.
- **`.tap` isolates side effects.** When you need logging, mutation, or assignment as a side effect without changing the return value, `.tap` makes that intent crystal clear.
