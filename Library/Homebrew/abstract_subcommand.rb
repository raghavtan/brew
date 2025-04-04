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
  module AbstractSubcommandable
    extend T::Helpers

    sig { returns(T::Hash[String, T.class_of(AbstractSubcommand)]) }
    def subcommands
      self.class.subcommands
    end

    sig { void }
    def self.included(base)
      base.extend(ClassMethods)

      base.singleton_class.prepend(Module.new do
        def inherited(subclass)
          super

          at_exit do
            subclass.register_all_subcommands
          end
        end
      end)
    end

    module ClassMethods
      sig { returns(T::Hash[String, T.class_of(AbstractSubcommand)]) }
      def subcommands
        @subcommands ||= T.let({}, T::Hash[String, T.class_of(AbstractSubcommand)])
      end

      sig { void }
      def register_all_subcommands
        constants.each do |const_name|
          const = const_get(const_name)
          if const.is_a?(Class) && const < AbstractSubcommand
            register_subcommand(const)
          end
        end
      end

      sig { params(subcommand_class: T.class_of(AbstractSubcommand), aliases: T::Array[String]).void }
      def register_subcommand(subcommand_class, aliases = [])
        primary_name = subcommand_class.command_name
        subcommands[primary_name] = subcommand_class

        aliases.each do |alias_name|
          subcommands[alias_name] = subcommand_class
        end
      end

      sig { params(block: T.proc.bind(CLI::Parser).void).void }
      def shared_args(&block)
        @shared_args_block = T.let(block, T.nilable(T.proc.void))
      end

      sig { returns(T.nilable(T.proc.void)) }
      def shared_args_block
        @shared_args_block
      end
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

      sig { returns(T::Array[String]) }
      def command_names
        parent_command_class.subcommands.select { |_, klass| klass == self }.keys
      end

      sig { returns(T.class_of(AbstractCommand)) }
      def parent_command_class
        parent_module = self.name.split("::")[0..-2].join("::")
        Object.const_get(parent_module)
      end

      sig { returns(CLI::Parser) }
      def parser
        parent_class = parent_command_class
        parser = CLI::Parser.new(self, &@parser_block)
        if parent_class.respond_to?(:shared_args_block) && parent_class.shared_args_block
          parser.instance_eval(&parent_class.shared_args_block)
        end

        parser
      end
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def common_args
      {
        global: args.global?,
        file: args.file,
        verbose: args.verbose?
      }
    end

    sig { abstract.void }
    def run; end
  end


  module SubcommandDispatcher
    sig { params(subcommand_name: T.nilable(String), args: T::Array[String]).returns(T::Boolean) }
    def dispatch_subcommand(subcommand_name, args = [])
      return false unless subcommand_name

      subcommand_class = subcommands[subcommand_name]
      return false unless subcommand_class

      subcommand_class.new(args).run
      true
    end

    sig { returns(String) }
    def available_subcommands_help
      cmd_list = subcommands.keys.uniq.sort
      return "" if cmd_list.empty?

      <<~EOS
        Available subcommands:
          #{cmd_list.join(", ")}
      EOS
    end
  end


  module TargetableCommand
    sig { params(loaded: T::Boolean).returns(T::Array[T.untyped]) }
    def get_targets(loaded: true)
      if args.all?
        Services::Formulae.available_services(
          loaded: loaded,
          skip_root: !Services::System.root?
        )
      elsif args.named_args.present?
        args.named_args.map { |f| Services::FormulaWrapper.new(Formulary.factory(f)) }
      else
        []
      end
    end
  end
end
