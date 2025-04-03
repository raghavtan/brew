# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "subcommandable"
require "subcommand_loader"

module Homebrew
  # A base class for commands that have subcommands.
  # Subclass this to create commands with subcommands.
  #
  # Example:
  #
  # ```ruby
  # class MyCommand < SubcommandableCommand
  #   cmd_args do
  #     usage_banner <<~EOS
  #       `my-command` [<subcommand>]
  #
  #       My command with subcommands.
  #     EOS
  #
  #     # Global options for all subcommands
  #     switch "--global-option", description: "A global option for all subcommands"
  #   end
  #
  #   subcommand "install", default: true do
  #     description "Install something"
  #     # Subcommand-specific options
  #     switch "--install-option", description: "An option specific to install"
  #   end
  #
  #   subcommand "remove" do
  #     description "Remove something"
  #     # Subcommand-specific options
  #     switch "--remove-option", description: "An option specific to remove"
  #   end
  # end
  # ```
  #
  # This will handle subcommand dispatch and option parsing.
  # The actual implementations should be placed in separate files:
  # - cmd/my-command/install.rb
  # - cmd/my-command/remove.rb
  class SubcommandableCommand < AbstractCommand
    include Subcommandable

    sig { override.void }
    def dispatch_subcommand(subcommand, subcommand_args)
      # Load the implementation for this subcommand
      subcommand_module = loader.load_subcommand(subcommand.name)

      if subcommand_module.nil?
        raise UsageError, "Subcommand implementation not found for #{subcommand.name}"
      end

      # Set the arguments for this subcommand
      @subcommand_args = T.let(subcommand_args, CLI::Args)

      # Call the module's run method with our current arguments
      # We expect the module to define a run method accepting the subcommand args
      if subcommand_module.respond_to?(:run)
        subcommand_module.run(subcommand_args)
      else
        raise UsageError, "Subcommand #{subcommand.name} does not implement run"
      end
    end

    private

    sig { returns(SubcommandLoader) }
    def loader
      @loader ||= T.let(SubcommandLoader.new(self.class.command_name), SubcommandLoader)
    end
  end
end
