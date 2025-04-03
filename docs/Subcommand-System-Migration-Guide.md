# Subcommand System Migration Guide

This guide explains how to migrate existing brew commands with subcommands to use the new subcommand system.

## Benefits of the New Subcommand System

- **Cleaner Code Organization**: Each subcommand is defined in its own class with focused responsibility
- **Improved Argument Handling**: Arguments are defined and validated at the subcommand level
- **Better Documentation**: Help text is generated on a per-subcommand basis
- **Enhanced Tab Completion**: Tab completion is more accurate as it only suggests relevant options
- **Reduced Duplication**: Shared arguments can be inherited by all subcommands
- **Simpler API**: Easier to create, maintain, and understand commands with subcommands

## Migration Steps

### 1. Include Required Modules

Update your command class to include the subcommand infrastructure:

```ruby
require "abstract_command"
require "abstract_subcommand"
require "subcommand_parser" 

module Homebrew
  module Cmd
    class YourCommand < AbstractCommand
      include AbstractSubcommandableMixin
      include SubcommandDispatchMixin
      
      # ...
    end
  end
end
```

### 2. Reorganize Command Arguments

Separate arguments into shared (common to all subcommands) and command-specific:

```ruby
# Define shared arguments that apply to all subcommands
shared_args do
  usage_banner <<~EOS
    `your-command` [<subcommand>]

    Your command description here.
  EOS

  # Add arguments that should be available to all subcommands
  switch "--common-flag", description: "Flag available to all subcommands"
end

# Define command-level arguments that don't apply to subcommands
cmd_args do
  # Only add arguments specific to the main command (if any)
  switch "--main-only-flag", description: "Flag only for the main command"
  
  # Specify valid subcommand names for better error messages
  named_args %w[subcommand1 subcommand2 subcommand3]
end
```

### 3. Update Run Method with Dispatch Logic

Replace complex case statements with the new dispatch system:

```ruby
def run
  # Any command-wide validation and setup
  setup_command_environment

  # Parse and extract subcommand name and arguments
  subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args.remaining_args, self)

  # Handle default subcommand if none specified
  if subcommand_name.nil?
    dispatch_subcommand("default_subcommand", remaining_args) || 
      raise(UsageError, "No subcommand specified")
    return
  end

  # Dispatch to the appropriate subcommand
  unless dispatch_subcommand(subcommand_name, remaining_args)
    raise UsageError, "Unknown subcommand: #{subcommand_name}"
  end
end
```

### 4. Create Subcommand Classes

Define each subcommand as a nested class:

```ruby
module Homebrew
  module Cmd
    class YourCommand
      # Define a subcommand
      class Subcommand1 < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `your-command subcommand1` [<options>]

            Subcommand1 description.
          EOS

          # Add subcommand-specific arguments
          switch "--subcommand-flag", description: "Flag for this subcommand only"
        end

        def run
          # Implement subcommand
          # Access arguments with args.flag_name?
        end
      end
      
      # More subcommands...
      
      # Register subcommands with their aliases
      register_subcommand(Subcommand1, ["subcommand1", "sub1", "s1"])
    end
  end
end
```

### 5. Access Arguments

In both the main command and subcommands, access arguments using the standard `args` method:

```ruby
def run
  # Shared arguments
  global_flag = args.common_flag?
  file_path = args.file
  
  # Subcommand-specific arguments 
  subcommand_flag = args.subcommand_flag?
  
  # Process arguments and implement command logic...
end
```

## Example: Converting Existing Commands

See the following files for examples of commands migrated to the new system:
- `bundle_new.rb`: Example migration of the `brew bundle` command
- `services_new.rb`: Example migration of the `brew services` command

## Testing

Write tests for your command using the `subcommand_system_spec.rb` as a reference.

## Best Practices

1. **Organize Shared Arguments Carefully**: Only include truly common arguments in `shared_args`
2. **Use Aliases for Usability**: Register common abbreviations as aliases
3. **Keep Subcommands Focused**: Each subcommand should do one thing well
4. **Default Behavior**: Provide a sensible default subcommand when none is specified
5. **Help Text**: Ensure each subcommand has clear usage examples

## Backward Compatibility

The new subcommand system is designed to be compatible with the existing Homebrew command infrastructure. No changes to the user-facing CLI interface are required.