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
    # @param command_class [Class] The parent command class
    # @return [Array<String, Array<String>>] The subcommand name and remaining arguments
    sig { 
      params(
        argv: T::Array[String], 
        parent_command: AbstractCommand
      ).returns([T.nilable(String), T::Array[String]]) 
    }
    def self.parse_subcommand(argv, parent_command)
      # Clone argv to avoid modifying the original
      args = argv.dup
      
      # Check for --help flag at the top level
      if args.include?("--help") || args.include?("-h")
        # Display the parent command's help including available subcommands
        puts parent_command.class.parser.generate_help_text
        puts "\n#{parent_command.available_subcommands_help}" if parent_command.respond_to?(:available_subcommands_help)
        exit 0
      end
      
      # Extract the subcommand name (first non-flag argument)
      subcommand_name = nil
      remaining_args = []
      
      # Handle the case where there are no arguments
      if args.empty?
        return [nil, args]
      end
      
      # Get the first argument that doesn't start with a dash
      # This should be the subcommand name
      first_non_flag = args.find { |arg| !arg.start_with?("-") }
      
      if first_non_flag
        subcommand_name = first_non_flag
        
        # Split args into before and after the subcommand
        subcommand_index = args.index(subcommand_name)
        before_args = args[0...subcommand_index] 
        after_args = args[(subcommand_index + 1)..]
        
        # Combine them with the subcommand removed
        remaining_args = before_args + after_args
      else
        # All arguments are flags, so there's no subcommand
        remaining_args = args
      end
      
      # Check for help on a specific subcommand
      if remaining_args.include?("--help") || remaining_args.include?("-h")
        command_class = parent_command.class.subcommands[subcommand_name]
        if command_class
          # Display help for the specific subcommand
          puts command_class.parser.generate_help_text
          exit 0
        end
      end
      
      [subcommand_name, remaining_args]
    end
  end
end