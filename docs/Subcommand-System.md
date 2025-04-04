# Homebrew Subcommand System

## Overview
The Homebrew subcommand system provides a modular approach to implementing commands with subcommands, organizing code into separate classes for each subcommand.

## Implementation Strategy
1. **Current Phase**: Merged implementation with both systems
  - Hidden `--new-system` flag
  - `HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM` environment variable
2. **Future**: Transition to new system with eventual removal of legacy code

## Migration Steps

### 1. Include Required Modules
```ruby
require "abstract_command"
require "abstract_subcommand"
require "subcommand_parser"
require "command_options"

module Homebrew
  module Cmd
    class YourCommand < AbstractCommand
      include AbstractSubcommandable
      include SubcommandDispatcher
      # ...
    end
  end
end
```

### 2. Implement Merged System
```ruby
def run
  if args.new_system? || ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"]
    run_new_system
  else
    run_legacy_system
  end
end

private

def run_new_system
  subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args.remaining_args, self)

  if subcommand_name.nil?
    dispatch_subcommand("default_subcommand", remaining_args) ||
      raise(UsageError, "No subcommand specified")
    return
  end

  unless dispatch_subcommand(subcommand_name, remaining_args)
    raise UsageError, "Unknown subcommand: #{subcommand_name}"
  end
end

def run_legacy_system
  # Original legacy implementation
end
```

### 3. Create Subcommand Classes
```ruby
# Base class to share functionality between subcommands (optional)
class CommandBaseSubcommand < AbstractSubcommand
  private

  def options
    CommandOptions.new(args)
  end
end

# Actual subcommand implementation
class Subcommand1 < CommandBaseSubcommand
  cmd_args do
    usage_banner <<~EOS
      `your-command subcommand1` [<options>]
      Subcommand1 description.
    EOS
    switch "--subcommand-flag", description: "Flag for this subcommand only"
  end

  def run
    # Implementation using parameter object instead of long parameter lists
    options = CommandOptions.new(args)
    YourModule::Commands::Subcommand1.run(
      argument1: args.named.first,
      **options.to_h
    )
  end
end
```

### 4. For Commands Working with Targets (Formulae, Casks)
```ruby
# Include the TargetableCommand module
class TargetSubcommand < AbstractSubcommand
  include TargetableCommand

  def run
    targets = get_targets(loaded: true)
    return if check_empty_targets(targets)
    # Process targets...
  end
end
```

## Testing
Test the new implementation with:
```bash
# Test with flag
brew command --new-system subcommand

# Test with environment variable
HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM=1 brew command subcommand
```

## Examples
Currently migrated commands:
- `brew bundle` - Merged implementation
- `brew services` - Merged implementation
