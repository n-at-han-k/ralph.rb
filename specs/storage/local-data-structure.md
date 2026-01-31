# Ralph Storage Architecture Specification

## Overview

The Ralph autonomous agent maintains persistent state across sessions through a modular storage system. All state is stored in the `.ralph/` directory within the project root, providing persistence for autonomous coding sessions, iteration history, context management, and task tracking.

## File Structure

### Root Directory Layout
```
.ralph/
├── ralph-loop.state.json     # Main loop state
├── ralph-history.json         # Complete iteration history  
├── ralph-context.md           # Persistent AI context
├── ralph-tasks.md             # Task management
└── ralph-opencode.config.json # OpenCode plugin configuration
```

## Storage Module Architecture

### Directory Structure
```
lib/ralph/storage/
├── history.rb      # Ralph::Storage::History class
├── state.rb        # Ralph::Storage::State class  
├── context.rb      # Ralph::Storage::Context class
├── tasks.rb        # Ralph::Storage::Tasks class + Task/Tasks models
└── .               # Main storage module file
```

### Module Organization

#### Ralph::Storage::History
**Purpose**: Manages complete iteration history across Ralph sessions.

**Responsibilities**:
- Save/load iteration history to `.ralph/ralph-history.json`
- Track struggle indicators and performance metrics
- Maintain chronology of all iterations
- Provide history analytics

**Data Structure**:
```ruby
RalphHistory = Struct.new(
  :iterations,          # Array<IterationHistory>
  :total_duration_ms,   # Integer
  :struggle_indicators, # StruggleIndicators
  keyword_init: true
)

IterationHistory = Struct.new(
  :iteration,           # Integer
  :started_at,          # String (ISO 8601)
  :ended_at,            # String (ISO 8601) 
  :duration_ms,         # Integer
  :tools_used,          # Hash<String, Integer>
  :files_modified,      # Array<String>
  :exit_code,           # Integer
  :completion_detected, # Boolean
  :errors               # Array<String>
)
```

**File Format**: JSON with iteration data, total duration, and struggle indicators.

#### Ralph::Storage::State
**Purpose**: Manages the active loop state for current Ralph session.

**Responsibilities**:
- Save/load loop state to `.ralph/ralph-loop.state.json`
- Track session metadata (iteration count, timing, configuration)
- Handle session lifecycle (start, stop, resume)
- File change detection via git snapshots
- OpenCode configuration management

**Data Structure**:
```ruby
RalphState = Struct.new(
  :active,              # Boolean
  :iteration,           # Integer
  :min_iterations,      # Integer
  :max_iterations,      # Integer
  :completion_promise,  # String
  :tasks_mode,          # Boolean
  :task_promise,        # String
  :prompt,              # String
  :started_at,          # String (ISO 8601)
  :model,               # String
  :agent,               # String
  keyword_init: true
)
```

**File Format**: JSON with loop configuration and session state.

**Additional Features**:
- `capture_file_snapshot()` - Git-based file state tracking
- `modified_files_since_snapshot()` - Change detection
- `ensure_ralph_config()` - OpenCode plugin configuration
- `load_plugins_from_config()` - Plugin discovery from config files

#### Ralph::Storage::Context
**Purpose**: Manages persistent AI context for maintaining conversational continuity.

**Responsibilities**:
- Load context from `.ralph/ralph-context.md`
- Clear context when sessions end
- Provide context for AI prompt building

**File Format**: Markdown file with structured context sections.

#### Ralph::Storage::Tasks
**Purpose**: Manages task tracking and workflow coordination.

**Responsibilities**:
- Save/load tasks to `.ralph/ralph-tasks.md`
- Parse and render task lists in markdown format
- Track task status (todo, in_progress, complete)
- Handle subtasks and task hierarchy
- Provide task analytics and display methods

**Data Structures**:
```ruby
Task = Struct.new(
  :text,              # String
  :status,            # Symbol (:todo, :in_progress, :complete)
  :subtasks,          # Array<Task>
  :original_line,     # String (for round-trip preservation)
  keyword_init: true
)

Tasks = Enumerable collection of Task objects
```

**File Format**: Markdown with checkbox syntax:
```markdown
# Ralph Tasks

- [ ] Task 1 description
- [/] Task 2 in progress
  - [ ] Subtask 2.1
  - [x] Subtask 2.2
- [x] Task 3 complete
```

## State Persistence Patterns

### Atomic Operations
All write operations use atomic file writing to prevent corruption:
- Write to temporary file first
- Rename/replace original file atomically
- Handle filesystem errors gracefully

### Error Handling
- All load operations handle missing files gracefully
- JSON parsing errors return empty/default states
- Filesystem errors are caught and logged
- State corruption recovery with fallback to empty state

### Directory Management
- `.ralph/` directory created automatically when needed
- Directory permissions set appropriately
- Cleanup operations preserve important state files

## Configuration Integration

### OpenCode Configuration
Storage::State manages OpenCode plugin configuration through:
- `.ralph/ralph-opencode.config.json` - Generated config file
- User config discovery: `~/.config/opencode/opencode.json`
- Project config discovery: `.ralph/opencode.json` or `.opencode/opencode.json`
- Plugin filtering and permission management

### Config File Format
```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["auth-plugin"],
  "permission": {
    "read": "allow",
    "edit": "allow",
    // ... all tool permissions
  }
}
```

## Migration Strategy

### Backward Compatibility
The original `State` module in `lib/ralph/state.rb` remains as a thin wrapper:
- Requires the new Storage module
- Delegates all existing methods to appropriate Storage classes
- Maintains identical public interface
- No functional changes to existing code

### Update Dependencies
Files requiring state management will need minimal updates:
- Add `require_relative "storage"` where needed
- All existing `State.method` calls continue to work unchanged
- Gradual migration to use Storage classes directly is optional

## Data Lifecycle

### Session Start
1. Load existing state from `.ralph/ralph-loop.state.json`
2. Check for active sessions (prevent concurrent loops)
3. Load history and context
4. Initialize new session state if needed
5. Create task file if tasks mode enabled

### During Session
1. Update state after each iteration
2. Append to history with iteration results
3. Track file changes via git snapshots
4. Update context as needed

### Session End
1. Clear active state flag
2. Save final history and state
3. Optionally clear context (based on configuration)
4. Cleanup temporary files

### Error Recovery
1. Automatic state clearing on crashes/interrupts
2. History preservation through graceful degradation
3. Context recovery from last good state
4. Task file preservation across all scenarios

## Security Considerations

### File Permissions
- `.ralph/` directory permissions restricted to owner
- Sensitive configuration files protected appropriately
- No world-readable state files

### Data Sanitization
- JSON validation on all loaded data
- Markdown sanitization for context/tasks
- Plugin configuration validation
- Safe handling of file paths and content

### Integrity Checks
- JSON schema validation for structured data
- File content checksums where appropriate
- Consistency checks between related files
- Recovery procedures for corrupted state