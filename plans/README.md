# Ralph.rb Implementation Plans

This directory contains comprehensive phased implementation plans for building Ralph.rb, a Ruby CLI that runs iterative AI development loops.

## Plans Overview

### [00-complete-implementation.md](./00-complete-implementation.md)
**Master Plan** - Coordinates all component implementations into a cohesive system with 8 phases from foundation to optimization.

### [01-cli-implementation.md](./01-cli-implementation.md)
**CLI Component** - Implements the command-line interface with Unix-style pipe support and all specified options.

### [02-loop-implementation.md](./02-loop-implementation.md)
**Core Loop Component** - Implements the main iteration management with context guards and termination conditions.

### [03-agents-implementation.md](./03-agents-implementation.md)
**Agent Integration** - Implements opencode CLI integration with JSON stream processing and process management.

### [04-metrics-implementation.md](./04-metrics-implementation.md)
**Metrics Component** - Implements real-time token usage and context calculation from JSON streams.

## Implementation Strategy

1. **Foundation First** - Start with the complete implementation plan for project setup
2. **Parallel Development** - CLI, Metrics, and Agents foundations can be developed simultaneously
3. **Integration Focus** - Loop implementation depends on the other three components
4. **Quality Gates** - Each phase includes verification criteria and testing requirements

## Key Dependencies

```
CLI → Loop → Agents → Metrics → CLI (for display)
```

- CLI requires Loop for execution
- Loop requires Agents for iteration execution  
- Loop requires Metrics for context monitoring
- Metrics requires Agents for JSON stream input
- CLI requires Metrics for progress display

## Verification Requirements

Every plan includes:
- ✅ Phase-specific deliverables
- ✅ Integration points with other components  
- ✅ Testing and quality assurance criteria
- ✅ Style compliance requirements (RuboCop)
- ✅ Final verification checklists

## Ruby Style Requirements

All implementations must follow the guidelines in `AGENTS.md`:
- No early returns or guard clauses
- Use `.then` and `.tap` for data flow
- No abbreviated variable names
- Full descriptive naming throughout

## Testing Commands

- **Run tests**: `bin/test`
- **Check style**: `bin/rubocop`

Both must pass before any component is considered complete.