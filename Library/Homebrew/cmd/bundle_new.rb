# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "abstract_subcommand"
require "subcommand_parser"

module Homebrew
  module Cmd
    class BundleNew < AbstractCommand
      include AbstractSubcommandableMixin
      include SubcommandDispatchMixin

      # Define shared arguments that apply to all bundle subcommands
      shared_args do
        usage_banner <<~EOS
          `bundle` [<subcommand>]

          Bundler for non-Ruby dependencies from Homebrew, Homebrew Cask, Mac App Store, Whalebrew and Visual Studio Code.
        EOS

        flag "--file=",
             description: "Read from or write to the `Brewfile` from this location."
        switch "--global",
               description: "Read from or write to the global Brewfile."
        switch "-v", "--verbose",
               description: "Print more verbose output."
      end

      # Define command-level arguments that don't apply to subcommands
      cmd_args do
        # No additional arguments specific to the main command
        # Since all functionality is in subcommands

        named_args %w[install dump cleanup check exec list sh env edit add remove]
      end

      sig { override.void }
      def run
        # Parse and extract subcommand name and the remaining arguments
        subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args.remaining_args, self)

        # Handle the case where no subcommand is specified
        if subcommand_name.nil?
          # Default to "install" if no subcommand is specified
          dispatch_subcommand("install", remaining_args) || raise(UsageError, "No subcommand specified. Try `brew bundle install`")
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

# Define the bundle subcommands as separate classes
module Homebrew
  module Cmd
    class BundleNew
      # Install subcommand
      class Install < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle install`

            Install and upgrade (by default) all dependencies from the `Brewfile`.
          EOS

          switch "--no-upgrade",
                 env: :bundle_no_upgrade,
                 description: "Don't run `brew upgrade` on outdated dependencies."
          switch "--upgrade",
                 description: "Run `brew upgrade` even if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          flag "--upgrade-formulae=",
               description: "Run `brew upgrade` on these formula, even if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          switch "-f", "--force",
                 description: "Run `install` with `--force`/`--overwrite`."
          switch "--cleanup",
                 env: :bundle_install_cleanup,
                 description: "Run cleanup after installation."
        end

        sig { override.void }
        def run
          # Keep this inside `run` to keep --help fast.
          require "bundle"
          require "bundle/commands/install"

          global = args.global?
          file = args.file
          
          no_upgrade = if args.upgrade?
            false
          else
            args.no_upgrade?
          end
          
          verbose = args.verbose?
          force = args.force?
          cleanup = args.cleanup?
          
          # Set upgrade formulae if specified
          Homebrew::Bundle.upgrade_formulae = args.upgrade_formulae

          # Run the install command
          Homebrew::Bundle::Commands::Install.run(
            global: global, 
            file: file, 
            no_upgrade: no_upgrade, 
            verbose: verbose, 
            force: force, 
            quiet: !verbose
          )

          # Run cleanup if specified
          if cleanup
            require "bundle/commands/cleanup"
            Homebrew::Bundle::Commands::Cleanup.run(
              global: global, 
              file: file, 
              force: true, 
              zap: false,
              dsl: Homebrew::Bundle::Commands::Install.dsl
            )
          end
        end
      end

      # Dump subcommand
      class Dump < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle dump`

            Write all installed casks/formulae/images/taps into a `Brewfile`.
          EOS

          switch "-f", "--force",
                 description: "Overwrite an existing `Brewfile`."
          switch "--describe",
                 env: :bundle_dump_describe,
                 description: "Add description comments above each line."
          switch "--no-restart",
                 description: "Do not add `restart_service` to formula lines."
          switch "--formula", "--brews",
                 description: "Dump Homebrew formula dependencies."
          switch "--cask", "--casks",
                 description: "Dump Homebrew cask dependencies."
          switch "--tap", "--taps",
                 description: "Dump Homebrew tap dependencies."
          switch "--mas",
                 description: "Dump Mac App Store dependencies."
          switch "--whalebrew",
                 description: "Dump Whalebrew dependencies."
          switch "--vscode",
                 description: "Dump VSCode extensions."
          switch "--no-vscode",
                 env: :bundle_dump_no_vscode,
                 description: "Don't dump VSCode extensions."
          switch "--all",
                 description: "Dump all dependencies."

          conflicts "--all", "--no-vscode"
          conflicts "--vscode", "--no-vscode"
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/dump"

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

          Homebrew::Bundle::Commands::Dump.run(
            global: global,
            file: file, 
            force: force,
            describe: args.describe?,
            no_restart: args.no_restart?,
            taps: args.taps? || args.all? || no_type_args,
            brews: args.brews? || args.all? || no_type_args,
            casks: args.casks? || args.all? || no_type_args,
            mas: args.mas? || args.all? || no_type_args,
            whalebrew: args.whalebrew? || args.all? || no_type_args,
            vscode: vscode
          )
        end
      end

      # Register subcommands with their aliases
      register_subcommand(Install, ["install", "upgrade"])
      register_subcommand(Dump, ["dump"])
      
      # Additional subcommands would be defined here...
    end
  end
end