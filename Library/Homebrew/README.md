# Homebrew Ruby API

This is the API for [Homebrew](https://github.com/Homebrew).

The main class you should look at is the {Formula} class (and classes linked from there). That's the class that's used to create Homebrew formulae (i.e. package descriptions). Assume anything else you stumble upon is private.

You may also find the [Formula Cookbook](https://docs.brew.sh/Formula-Cookbook) and [Ruby Style Guide](https://rubystyle.guide) helpful in creating formulae.

Good luck!

# Homebrew Core Library

This is the core library of Homebrew.

## SubcommandFramework

Homebrew commands often have subcommands (like `brew bundle install` or `brew services start`). The `SubcommandFramework` module provides a consistent way to handle subcommands, which helps with:

- Argument parsing
- Documentation generation
- Shell completion
- Subcommand routing

### Using the SubcommandFramework

1. Create a module for your command (e.g., `Homebrew::SubcommandMyCommand`)
2. Include the `Homebrew::SubcommandFramework` module
3. Define the `COMMAND_NAME` constant with your primary command name
4. Define the `DEFAULT_SUBCOMMAND` constant (optional)
5. Define the `GLOBAL_OPTIONS` hash for options that apply to all subcommands (optional)
6. Define the `SUBCOMMANDS` hash with your subcommands, their descriptions, and arguments
7. Implement the methods for each subcommand

### Example

```ruby
module Homebrew
  module SubcommandMyCommand
    include Homebrew::SubcommandFramework

    COMMAND_NAME = "mycommand"
    DEFAULT_SUBCOMMAND = "list" # Optional, defaults to first subcommand

    # Global options applicable to all subcommands (optional)
    GLOBAL_OPTIONS = {
      "--option1=" => "Description of option1",
      "--flag1" => "Description of flag1",
    }.freeze

    # Define each subcommand with its description and arguments
    SUBCOMMANDS = {
      "list" => {
        description: "List all items",
        args: [
          [:switch, "--json", {
            description: "Output as JSON."
          }],
        ],
      },
      "add" => {
        description: "Add a new item",
        args: [
          [:switch, "--force", {
            description: "Force add the item"
          }],
        ],
      },
      # Add more subcommands as needed
    }.freeze

    class << self
      extend T::Sig

      # Implement each subcommand as a method
      sig { params(args: Homebrew::CLI::Args).void }
      def list(args)
        # Implementation for the list subcommand
      end

      sig { params(args: Homebrew::CLI::Args).void }
      def add(args)
        # Implementation for the add subcommand
      end
    end
  end
end
```

### Integration with Existing Commands

To integrate with existing command infrastructure, you'll need to:

1. Create your module as described above
2. Update the existing command class to use your module
3. Map the parsed args to an array of strings to pass to your module's `route_subcommand` method

```ruby
module Homebrew
  module Cmd
    class MyCommand < AbstractCommand
      # Command definition with cmd_args...

      sig { override.void }
      def run
        # Map args to argv
        argv = []

        # Add named args (subcommand and its arguments)
        argv.concat(args.named)

        # Add option flags
        argv << "--option1=#{args.option1}" if args.option1
        argv << "--flag1" if args.flag1?

        # Route to your subcommand module
        SubcommandMyCommand.route_subcommand(argv)
      end
    end
  end
end
```

### Benefits

- **Consistent handling** of subcommands across different Homebrew commands
- **Automatic documentation** for subcommands and their options
- **Better shell completion** that includes subcommands
- **Cleaner code** with reduced duplication of argument handling logic
- **Improved user experience** for command-line interactions
