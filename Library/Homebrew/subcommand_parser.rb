# typed: strong
# frozen_string_literal: true

require "abstract_subcommand"
require "cli/error"

module Homebrew
  # Helper module for parsing subcommands and their arguments
  module SubcommandParser
    # Parse command line arguments for a command with subcommands
    #
    # This extracts the subcommand name and remaining arguments,
    # handling --help flags appropriately.
    #
    # @param argv [Array<String>] The command line arguments
    # @param parent_command [AbstractCommand] The parent command instance
    # @return [Array<String, Array<String>>] The subcommand name and remaining arguments
    sig {
      params(
        argv: T::Array[String],
        parent_command: AbstractCommand
      ).returns([T.nilable(String), T::Array[String]])
    }
    def self.parse_subcommand(argv, parent_command)
      args = argv.dup

      if handle_help_flag(args, parent_command)
        exit 0
      end

      subcommand_name, remaining_args = extract_subcommand(args)

      if handle_subcommand_help(remaining_args, subcommand_name, parent_command)
        exit 0
      end

      [subcommand_name, remaining_args]
    end

    private

    sig {
      params(
        args: T::Array[String],
        parent_command: AbstractCommand
      ).returns(T::Boolean)
    }
    def self.handle_help_flag(args, parent_command)
      if args.include?("--help") || args.include?("-h")
        puts parent_command.class.parser.generate_help_text
        if parent_command.respond_to?(:available_subcommands_help)
          puts "\n#{parent_command.available_subcommands_help}"
        end
        return true
      end
      false
    end

    sig { params(args: T::Array[String]).returns([T.nilable(String), T::Array[String]]) }
    def self.extract_subcommand(args)
      return [nil, args] if args.empty?

      first_non_flag = args.find { |arg| !arg.start_with?("-") }

      if first_non_flag
        subcommand_name = first_non_flag

        subcommand_index = args.index(subcommand_name)
        before_args = args[0...subcommand_index]
        after_args = args[(subcommand_index + 1)..]

        remaining_args = before_args + after_args
        return [subcommand_name, remaining_args]
      end

      [nil, args]
    end

    sig {
      params(
        args: T::Array[String],
        subcommand_name: T.nilable(String),
        parent_command: AbstractCommand
      ).returns(T::Boolean)
    }
    def self.handle_subcommand_help(args, subcommand_name, parent_command)
      return false unless args.include?("--help") || args.include?("-h")
      return false unless subcommand_name

      if parent_command.respond_to?(:subcommands)
        command_class = parent_command.subcommands[subcommand_name]
        if command_class
          puts command_class.parser.generate_help_text
          return true
        end
      end

      false
    end
  end
end
