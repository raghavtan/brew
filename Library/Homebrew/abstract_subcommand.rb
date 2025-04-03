# typed: strong
# frozen_string_literal: true

require "abstract_command"
require "cli/parser"

module Homebrew
  # This class provides a framework for implementing subcommands within a brew command.
  # It extends the AbstractCommand functionality by:
  #
  # 1. Providing a clean hierarchy of command/subcommand relationships
  # 2. Allowing subcommands to define their own specific arguments
  # 3. Supporting inheritance of parent command arguments where applicable
  # 4. Generating proper help text for both main commands and subcommands
  # 5. Facilitating improved tab completion by properly organizing command options
  #
  # @api public
  class AbstractSubcommandableMixin
    extend T::Helpers

    module ClassMethods
      # Maps subcommand names to their corresponding classes
      sig { returns(T::Hash[String, T.class_of(AbstractSubcommand)]) }
      def subcommands
        @subcommands ||= T.let({}, T::Hash[String, T.class_of(AbstractSubcommand)])
      end

      # Define a subcommand that is triggerable by one or more alias names
      sig { params(subcommand_class: T.class_of(AbstractSubcommand), aliases: T::Array[String]).void }
      def register_subcommand(subcommand_class, aliases = [])
        primary_name = subcommand_class.command_name
        subcommands[primary_name] = subcommand_class
        
        aliases.each do |alias_name|
          subcommands[alias_name] = subcommand_class
        end
      end

      # Defines shared arguments that apply to all subcommands
      sig { params(block: T.proc.bind(CLI::Parser).void).void }
      def shared_args(&block)
        @shared_args_block = T.let(block, T.nilable(T.proc.void))
      end

      # Access the shared arguments block to apply to subcommands
      sig { returns(T.nilable(T.proc.void)) }
      def shared_args_block
        @shared_args_block
      end
    end

    # Include the class methods
    sig { void }
    def self.included(base)
      base.extend(ClassMethods)
    end
  end

  # Base class for all subcommands
  # 
  # Subcommands implement their own argument parsing and help text generation
  # while inheriting shared arguments from their parent command.
  #
  # @api public
  class AbstractSubcommand < AbstractCommand
    extend T::Helpers

    abstract!

    class << self
      sig { returns(String) }
      def command_name
        require "utils"

        Utils.underscore(T.must(name).split("::").fetch(-1))
             .tr("_", "-")
      end

      # Get all the names (primary and aliases) for this subcommand
      sig { returns(T::Array[String]) }
      def command_names
        # Get parent command's subcommands hash
        parent_command_class.subcommands.select { |_, klass| klass == self }.keys
      end

      # Returns the parent command class for this subcommand
      sig { returns(T.class_of(AbstractCommand)) }
      def parent_command_class
        # Extract parent command class from module hierarchy
        parent_module = self.name.split("::")[0..-2].join("::")
        Object.const_get(parent_module)
      end

      # Create a parser that inherits shared arguments from the parent command
      sig { returns(CLI::Parser) }
      def parser
        parent_class = parent_command_class
        
        # Create a new parser with our specific cmd_args block
        parser = CLI::Parser.new(self, &@parser_block)
        
        # Apply the parent's shared arguments if available
        if parent_class.respond_to?(:shared_args_block) && parent_class.shared_args_block
          parser.instance_eval(&parent_class.shared_args_block)
        end
        
        parser
      end
    end

    # The implementation for the subcommand
    sig { abstract.void }
    def run; end
  end

  # Adds subcommand dispatching capabilities to AbstractCommand
  # This module should be included in command classes that want to support subcommands
  module SubcommandDispatchMixin
    # Dispatch to the appropriate subcommand based on the arguments
    sig { params(subcommand_name: T.nilable(String), args: T::Array[String]).returns(T::Boolean) }
    def dispatch_subcommand(subcommand_name, args = [])
      return false unless subcommand_name

      subcommand_class = self.class.subcommands[subcommand_name]
      return false unless subcommand_class

      # Create and run the subcommand with the remaining arguments
      subcommand_class.new(args).run
      true
    end
    
    # Generate a list of available subcommands for help text
    sig { returns(String) }
    def available_subcommands_help
      subcommands = self.class.subcommands.keys.uniq.sort
      return "" if subcommands.empty?
      
      <<~EOS
        Available subcommands:
          #{subcommands.join(", ")}
      EOS
    end
  end
end