# typed: strict
# frozen_string_literal: true

module Homebrew
  # Implementation of the `brew bundle install` subcommand
  module Install
    extend T::Sig

    module_function

    sig { params(args: CLI::Args).void }
    def run(args)
      # Keep this inside `run` to keep --help fast.
      require "bundle"
      require "bundle/commands/install"

      # Extract relevant options from args
      global = args.global?
      file = args.file
      no_upgrade = !args.upgrade?
      verbose = args.verbose?
      force = args.force?
      cleanup = args.cleanup?

      # Run the install command
      Homebrew::Bundle::Commands::Install.run(
        global:,
        file:,
        no_upgrade:,
        verbose:,
        force:,
        quiet: args.quiet?,
      )

      # Handle cleanup if needed
      if cleanup || (ENV.fetch("HOMEBREW_BUNDLE_INSTALL_CLEANUP", nil) && args.global?)
        require "bundle/commands/cleanup"
        Homebrew::Bundle::Commands::Cleanup.run(
          global:,
          file:,
          force: true,
          zap: args.zap?,
          dsl: Homebrew::Bundle::Commands::Install.dsl,
        )
      end
    end
  end
end
