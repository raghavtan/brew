# typed: strict
# frozen_string_literal: true

module Homebrew
  # A module that can be included in a command to support subcommands.
  # This provides a unified DSL for defining subcommands, their options,
  # and handling routing to the appropriate subcommand handler.
  #
  # Usage:
  #
  # ```ruby
  # class MyCommand < AbstractCommand
  #   include Homebrew::Subcommandable
  #
  #   cmd_args do
  #     # Global options for the command
  #     # ...
  #   end
  #
  #   subcommand "install" do
  #     description "Install the thing"
  #     switch "--some-option", description: "Do something special"
  #     # Subcommand-specific options
  #   end
  #
  #   # Define the run method as normal, which will now dispatch to subcommands
  # end
  # ```
  module Subcommandable
    sig { params(base: Module).void }
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class methods to be added to the including command class
    module ClassMethods
      sig { returns(T::Hash[String, Subcommand]) }
      def subcommands
        @subcommands ||= T.let({}, T::Hash[String, Subcommand])
      end

      sig { returns(T.nilable(String)) }
      def default_subcommand
        @default_subcommand ||= T.let(nil, T.nilable(String))
      end

      sig { params(name: String, default: T::Boolean, block: T.proc.bind(CLI::Parser).void).void }
      def subcommand(name, default: false, &block)
        cmd = Subcommand.new(name, self, &block)
        subcommands[name] = cmd
        cmd.aliases.each do |alias_name|
          subcommands[alias_name] = cmd
        end
        @default_subcommand = name if default
      end
    end

    # A class representing a subcommand with its own options and description
    class Subcommand
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Array[String]) }
      attr_reader :aliases

      sig { returns(T.class_of(AbstractCommand)) }
      attr_reader :parent_command

      sig { returns(T.nilable(String)) }
      attr_reader :description

      sig { returns(CLI::Parser) }
      attr_reader :parser

      sig { params(name: String, parent_command: T.class_of(AbstractCommand), block: T.proc.bind(CLI::Parser).void).void }
      def initialize(name, parent_command, &block)
        @name = name
        @parent_command = parent_command
        @aliases = T.let([], T::Array[String])
        @description = T.let(nil, T.nilable(String))
        @parser = T.let(CLI::Parser.new, CLI::Parser)
        @options = T.let([], T::Array[Symbol])

        instance_eval(&block) if block
      end

      sig { params(description_text: String).void }
      def description(description_text)
        @description = description_text
      end

      sig { params(alias_names: String).void }
      def alias_as(*alias_names)
        @aliases.concat(alias_names)
      end

      sig { params(args: CLI::Args).void }
      def run(args)
        # This method should be overridden by the including command
        raise NoMethodError, "Subcommand #{name} does not implement run"
      end
    end

    sig { returns(T.nilable(String)) }
    def current_subcommand
      @current_subcommand
    end

    sig { returns(CLI::Args) }
    def subcommand_args
      @subcommand_args
    end

    sig { void }
    def run
      subcommand_name = args.named.first

      # If no subcommand is given, use the default if defined
      if subcommand_name.nil? && self.class.default_subcommand
        subcommand_name = self.class.default_subcommand
      end

      # Get the corresponding subcommand
      subcommand = self.class.subcommands[subcommand_name]

      if subcommand.nil?
        if subcommand_name.nil?
          # No subcommand provided and no default
          raise UsageError, "No subcommand specified. Valid subcommands: #{self.class.subcommands.keys.uniq.join(", ")}"
        else
          # Invalid subcommand
          raise UsageError, "Unknown subcommand: #{subcommand_name}. Valid subcommands: #{self.class.subcommands.keys.uniq.join(", ")}"
        end
      end

      # Parse arguments for this specific subcommand
      # Remove the subcommand name from the arguments
      remaining_args = args.named.dup
      remaining_args.shift if remaining_args.first == subcommand_name

      # Store the current subcommand for reference
      @current_subcommand = T.let(subcommand_name, T.nilable(String))

      # Create a new parser specific to this subcommand and parse the remaining args
      @subcommand_args = T.let(subcommand.parser.parse(ARGV.reject { |arg| arg == subcommand_name }), CLI::Args)

      # Call the subcommand's run method
      dispatch_subcommand(subcommand, @subcommand_args)
    end

    sig { params(subcommand: Subcommand, subcommand_args: CLI::Args).void }
    def dispatch_subcommand(subcommand, subcommand_args)
      # Subclasses should override this method to handle dispatching to the actual implementation
      raise NoMethodError, "Command #{self.class.name} does not implement dispatch_subcommand"
    end
  end
end
