# Homebrew Subcommand Migration Guide

This guide provides instructions for migrating existing Homebrew commands with subcommands to use the new unified subcommand system.

## Overview

The new subcommand system provides a consistent way to:

1. Define subcommands and their specific options
2. Parse arguments correctly for each subcommand
3. Generate appropriate documentation and shell completions
4. Maintain backward compatibility

## Migration Steps

### Step 1: Convert the Main Command Class

First, update your main command class to inherit from `SubcommandableCommand` and define subcommands:

```ruby
# Old approach
class MyCommand < AbstractCommand
  cmd_args do
    # Global options and command definition
  end

  def run
    # Subcommand dispatch logic
  end
end

# New approach
class MyCommand < SubcommandableCommand
  cmd_args do
    # Only global options that apply to all subcommands
  end

  # Define subcommands with their specific options
  subcommand "install", default: true do
    description "Install something"
    # Subcommand-specific options
    switch "--install-option", description: "An option specific to install"
  end

  subcommand "remove" do
    description "Remove something"
    # Subcommand-specific options
    switch "--remove-option", description: "An option specific to remove"
  end
end
```

### Step 2: Create Subcommand Implementation Files

Create a directory for your subcommand implementations:

```
mkdir -p Library/Homebrew/cmd/your-command
```

Create implementation files for each subcommand:

```ruby
# Library/Homebrew/cmd/your-command/install.rb
module Homebrew
  module Install
    extend T::Sig

    module_function

    sig { params(args: CLI::Args).void }
    def run(args)
      # Implementation of the install subcommand
    end
  end
end
```

### Step 3: Handle Special Cases

Some subcommands might need special handling. You can override the `dispatch_subcommand` method:

```ruby
def dispatch_subcommand(subcommand, subcommand_args)
  # Handle special cases
  if subcommand.name == "special-case"
    # Special handling
    return
  end

  # Default handling for regular subcommands
  super
end
```

### Step 4: Test and Verify

Test that your command works as expected:

1. Ensure all subcommands are correctly dispatched
2. Verify that options are parsed correctly for each subcommand
3. Check that help text and documentation are generated correctly

## Advanced Features

### Default Subcommands

You can specify a default subcommand to run when no subcommand is provided:

```ruby
subcommand "install", default: true do
  # ...
end
```

### Subcommand Aliases

You can define aliases for subcommands:

```ruby
subcommand "cleanup" do
  alias_as "clean"
  # ...
end
```

### Subcommand-Specific Options

Options can be specific to certain subcommands:

```ruby
subcommand "install" do
  switch "--special-option", description: "Only for install"
end
```

### Global Options

Global options are defined in the main `cmd_args` block and apply to all subcommands.

## Example Migration: Before and After

### Before

A typical command with subcommands before migration:

```ruby
class Bundle < AbstractCommand
  cmd_args do
    # All options defined here
  end

  def run
    subcommand = args.named.first

    case subcommand
    when "install"
      # Handle install
    when "clean"
      # Handle clean
    else
      # Handle unknown subcommand
    end
  end
end
```

### After

The same command after migration:

```ruby
class Bundle < SubcommandableCommand
  cmd_args do
    # Only global options here
  end

  subcommand "install", default: true do
    # Install-specific options
  end

  subcommand "clean" do
    # Clean-specific options
  end

  # Automatic dispatching to subcommand implementations
end
```

## Benefits

- Clearer separation of concerns
- Better documentation generation
- Improved shell completion
- Consistent argument handling
- Properly scoped options
