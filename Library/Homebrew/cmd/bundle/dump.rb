# typed: strict
# frozen_string_literal: true

module Homebrew
  # Implementation of the `brew bundle dump` subcommand
  module Dump
    extend T::Sig

    module_function

    sig { params(args: CLI::Args).void }
    def run(args)
      # Keep this inside `run` to keep --help fast.
      require "bundle"
      require "bundle/commands/dump"

      # Extract relevant options from args
      global = args.global?
      file = args.file
      force = args.force?

      # Determine what to dump
      no_type_args = !args.brews? && !args.casks? && !args.taps? && !args.mas? && !args.whalebrew? && !args.vscode?

      vscode = if args.no_vscode?
        false
      elsif args.vscode?
        true
      else
        no_type_args
      end

      # Run the dump command
      Homebrew::Bundle::Commands::Dump.run(
        global:,
        file:,
        force:,
        describe: args.describe?,
        no_restart: args.no_restart?,
        taps: args.taps? || no_type_args,
        brews: args.brews? || no_type_args,
        casks: args.casks? || no_type_args,
        mas: args.mas? || no_type_args,
        whalebrew: args.whalebrew? || no_type_args,
        vscode:,
      )
    end
  end
end
