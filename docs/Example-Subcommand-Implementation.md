# Example Subcommand Implementation

This document provides a complete example of implementing a new brew command using the subcommand system.

## Example Command: `brew example`

Let's create a hypothetical `brew example` command with several subcommands.

### File Structure: `/Library/Homebrew/cmd/example.rb`

```ruby
# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "abstract_subcommand"
require "subcommand_parser"

module Homebrew
  module Cmd
    class Example < AbstractCommand
      include AbstractSubcommandableMixin
      include SubcommandDispatchMixin

      # Define shared arguments that apply to all example subcommands
      shared_args do
        usage_banner <<~EOS
          `example` [<subcommand>]

          Example command to demonstrate the new subcommand system.
        EOS

        switch "--verbose",
               description: "Print more verbose output."
        switch "--json",
               description: "Output information in JSON format."
      end

      # Define command-level arguments
      cmd_args do
        # No additional command-level arguments

        # List valid subcommands for better error messages
        named_args %w[list create update delete]
      end

      sig { override.void }
      def run
        # Parse and extract subcommand name and the remaining arguments
        subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args.remaining_args, self)

        # Handle case where no subcommand is specified
        if subcommand_name.nil?
          # Default to "list" subcommand if none specified
          dispatch_subcommand("list", remaining_args) ||
            raise(UsageError, "No subcommand specified. Try `brew example list`")
          return
        end

        # Dispatch to the appropriate subcommand
        unless dispatch_subcommand(subcommand_name, remaining_args)
          raise UsageError, "Unknown subcommand: #{subcommand_name}"
        end
      end
    end
  end
end

# Define the subcommands as separate classes
module Homebrew
  module Cmd
    class Example
      # List subcommand
      class List < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `example list` [`--installed`]

            List available examples or just installed ones.
          EOS

          switch "--installed",
                 description: "Only list installed examples."
        end

        sig { override.void }
        def run
          # Access arguments
          json_output = args.json?
          verbose = args.verbose?
          installed_only = args.installed?

          # Implement subcommand logic
          if json_output
            puts '{"examples": ["example1", "example2"]}'
          else
            if verbose
              puts "Listing examples with verbose output"
            end

            puts "Available examples:"
            puts "- example1"
            puts "- example2"
          end
        end
      end

      # Create subcommand
      class Create < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `example create` <name> [`--template`=<template>]

            Create a new example with the given name.
          EOS

          flag "--template=",
               description: "Specify a template to use."

          named_args [:name], min: 1
        end

        sig { override.void }
        def run
          # Access arguments
          verbose = args.verbose?
          template = args.template
          name = args.named.first

          # Implement subcommand logic
          template ||= "default"

          if verbose
            puts "Creating example '#{name}' with template '#{template}'"
          else
            puts "Created example '#{name}'"
          end
        end
      end

      # Update subcommand
      class Update < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `example update` <name> [`--force`]

            Update the specified example.
          EOS

          switch "--force",
                 description: "Force update even if not needed."

          named_args [:name], min: 1
        end

        sig { override.void }
        def run
          # Access arguments
          verbose = args.verbose?
          force = args.force?
          name = args.named.first

          # Implement subcommand logic
          status = if force
            "forced update"
          else
            "normal update"
          end

          if verbose
            puts "Updating example '#{name}' (#{status})"
          else
            puts "Updated example '#{name}'"
          end
        end
      end

      # Delete subcommand
      class Delete < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `example delete` <name> [`--force`]

            Delete the specified example.
          EOS

          switch "--force",
                 description: "Force deletion without confirmation."

          named_args [:name], min: 1, max: 1
        end

        sig { override.void }
        def run
          # Access arguments
          verbose = args.verbose?
          force = args.force?
          name = args.named.first

          # Implement subcommand logic
          unless force
            # In a real implementation, this would prompt for confirmation
            puts "Confirmation skipped for this example"
          end

          if verbose
            puts "Deleting example '#{name}' with verbose output"
          else
            puts "Deleted example '#{name}'"
          end
        end
      end
    end
  end
end

# Register the command in the Homebrew module
module Homebrew
  module_function

  def example
    Cmd::Example.new(ARGV).run
  end
end
```

### Registering Command Aliases

If you want to provide aliases for your subcommands, you can register them explicitly:

```ruby
# Add this after defining all subcommand classes
module Homebrew
  module Cmd
    class Example
      # Register list command with aliases
      register_subcommand "list", ["ls", "l"]

      # Register create command with aliases
      register_subcommand "create", ["new", "add"]

      # Register update command with aliases
      register_subcommand "update", ["edit", "modify"]

      # Register delete command with aliases
      register_subcommand "delete", ["remove", "rm"]
    end
  end
end
```

### Testing Your Command

Create a test file at `/Library/Homebrew/test/cmd/example_spec.rb`:

```ruby
# typed: false
# frozen_string_literal: true

require "cmd/example"
require "cmd/shared_examples/args_parse"

describe "brew example" do
  it "has proper implementation structure" do
    expect(Homebrew.method(:example).owner).to eq(Homebrew)
    expect(Homebrew::Cmd::Example).to be_a(Class)
    expect(Homebrew::Cmd::Example).to respond_to(:subcommands)
  end

  describe "subcommand implementations" do
    it "defines all required subcommands" do
      # Check that all expected subcommands are registered
      expected_subcommands = %w[
        list create update delete
      ]

      registered_subcommands = Homebrew::Cmd::Example.subcommands.keys

      expected_subcommands.each do |subcommand|
        expect(registered_subcommands).to include(subcommand)
      end
    end

    it "has proper List subcommand" do
      list_class = Homebrew::Cmd::Example::List
      expect(list_class.superclass).to eq(Homebrew::AbstractSubcommand)

      parser = list_class.parser
      expect(parser.instance_variable_get(:@parser).to_s).to include("--installed")
    end

    it "has proper Create subcommand" do
      create_class = Homebrew::Cmd::Example::Create
      expect(create_class.superclass).to eq(Homebrew::AbstractSubcommand)

      parser = create_class.parser
      expect(parser.instance_variable_get(:@parser).to_s).to include("--template")
    end
  end

  describe "dispatching mechanism" do
    before do
      # Stub out the actual execution to avoid side effects
      allow_any_instance_of(Homebrew::Cmd::Example::List).to receive(:run)
      allow_any_instance_of(Homebrew::Cmd::Example::Create).to receive(:run)
      allow_any_instance_of(Homebrew::Cmd::Example::Update).to receive(:run)
      allow_any_instance_of(Homebrew::Cmd::Example::Delete).to receive(:run)

      # Stub the parse_subcommand method for testing
      allow(Homebrew::SubcommandParser).to receive(:parse_subcommand).and_return(["list", []])
    end

    it "dispatches to the correct subcommand" do
      example = Homebrew::Cmd::Example.new([])
      expect_any_instance_of(Homebrew::Cmd::Example::List).to receive(:run)
      example.run
    end

    it "defaults to list when no subcommand is specified" do
      allow(Homebrew::SubcommandParser).to receive(:parse_subcommand).and_return([nil, []])
      example = Homebrew::Cmd::Example.new([])
      expect_any_instance_of(Homebrew::Cmd::Example::List).to receive(:run)
      example.run
    end

    it "raises an error for unknown subcommands" do
      allow(Homebrew::SubcommandParser).to receive(:parse_subcommand).and_return(["unknown", []])
      example = Homebrew::Cmd::Example.new([])
      expect { example.run }.to raise_error(UsageError, /Unknown subcommand: unknown/)
    end
  end
end
```

## Common Patterns

### Handling Common Actions Across Subcommands

If you need to perform common actions across multiple subcommands, you can create a shared helper method:

```ruby
module Homebrew
  module Cmd
    class Example
      class << self
        def common_setup(verbose)
          puts "Performing common setup..." if verbose
          # Common setup code
        end
      end

      # Use in subcommands
      class SomeSubcommand < AbstractSubcommand
        def run
          verbose = args.verbose?
          Example.common_setup(verbose)
          # Subcommand-specific code
        end
      end
    end
  end
end
```

### Processing Multiple Items

When processing multiple items in a subcommand:

```ruby
class MultiSubcommand < AbstractSubcommand
  cmd_args do
    usage_banner <<~EOS
      `example multi` <item> [<item> ...]

      Process multiple items.
    EOS

    named_args [:item], min: 1
  end

  def run
    args.named.each do |item|
      process_item(item)
    end
  end

  private

  def process_item(item)
    puts "Processing #{item}"
    # Item processing logic
  end
end
```

### Loading Additional Dependencies

Load additional dependencies only when needed:

```ruby
class SpecializedSubcommand < AbstractSubcommand
  def run
    # Load dependencies only when this subcommand is invoked
    require "specialized_library"

    # Subcommand implementation
  end
end
```

## Next Steps

After implementing your command, you'll need to:

1. **Run tests**: `brew test-bot --only-formulae --only-tap=homebrew/core`
2. **Check style**: `brew style`
3. **Submit your PR**: Follow the usual Homebrew contribution guidelines

For more information, see the [Subcommand System Migration Guide](Subcommand-System-Migration-Guide.md).
