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
             description: "Read from or write to the `Brewfile` from this location. " \
                          "Use `--file=-` to pipe to stdin/stdout."
        switch "--global",
               description: "Read from or write to the global Brewfile."
        switch "-v", "--verbose",
               description: "Print more verbose output."
      end

      sig { override.void }
      def run
        # Keep this inside `run` to keep --help fast.
        require "bundle"

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

# Define the bundle subcommands
module Homebrew
  module Cmd
    class BundleNew
      # Install subcommand
      class Install < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle install`

            Install and upgrade (by default) all dependencies from the `Brewfile`.

            You can specify the `Brewfile` location using `--file` or by setting the `$HOMEBREW_BUNDLE_FILE` environment variable.

            You can skip the installation of dependencies by adding space-separated values to one or more of the following environment variables: `$HOMEBREW_BUNDLE_BREW_SKIP`, `$HOMEBREW_BUNDLE_CASK_SKIP`, `$HOMEBREW_BUNDLE_MAS_SKIP`, `$HOMEBREW_BUNDLE_WHALEBREW_SKIP`, `$HOMEBREW_BUNDLE_TAP_SKIP`.
          EOS

          switch "--no-upgrade",
                 env: :bundle_no_upgrade,
                 description: "Don't run `brew upgrade` on outdated dependencies. " \
                              "Note they may still be upgraded by `brew install` if needed."
          switch "--upgrade",
                 description: "Run `brew upgrade` even if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          flag "--upgrade-formulae=", "--upgrade-formula=",
               description: "Run `brew upgrade` on these comma-separated formulae, even if " \
                            "`$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          switch "-f", "--force",
                 description: "Run `install` with `--force`/`--overwrite`."
          switch "--cleanup",
                 env: :bundle_install_cleanup,
                 description: "Run cleanup after installation."
        end

        sig { override.void }
        def run
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
                 description: "Add description comments above each line, unless the " \
                              "dependency does not have a description."
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

      # Cleanup subcommand
      class Cleanup < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle cleanup`

            Uninstall all dependencies not present in the `Brewfile`.

            This workflow is useful for maintainers or testers who regularly install lots of formulae.
          EOS

          switch "-f", "--force",
                 description: "Actually perform the cleanup operations."
          switch "--zap",
                 description: "Clean up casks using the `zap` command instead of `uninstall`."
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/cleanup"

          global = args.global?
          file = args.file
          force = args.force?
          zap = args.zap?

          Homebrew::Bundle::Commands::Cleanup.run(
            global: global,
            file: file,
            force: force,
            zap: zap
          )
        end
      end

      # Check subcommand
      class Check < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle check`

            Check if all dependencies present in the `Brewfile` are installed.
          EOS

          switch "--no-upgrade",
                 env: :bundle_no_upgrade,
                 description: "Don't check for outdated dependencies."
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/check"

          global = args.global?
          file = args.file
          no_upgrade = args.no_upgrade?
          verbose = args.verbose?

          Homebrew::Bundle::Commands::Check.run(
            global: global,
            file: file,
            no_upgrade: no_upgrade,
            verbose: verbose
          )
        end
      end

      # List subcommand
      class List < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle list`

            List all dependencies present in the `Brewfile`.
          EOS

          switch "--all",
                 description: "List all dependencies."
          switch "--formula", "--brews",
                 description: "List Homebrew formula dependencies."
          switch "--cask", "--casks",
                 description: "List Homebrew cask dependencies."
          switch "--tap", "--taps",
                 description: "List Homebrew tap dependencies."
          switch "--mas",
                 description: "List Mac App Store dependencies."
          switch "--whalebrew",
                 description: "List Whalebrew dependencies."
          switch "--vscode",
                 description: "List VSCode extensions."
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/list"

          global = args.global?
          file = args.file

          no_type_args = !args.brews? && !args.casks? && !args.taps? && !args.mas? && !args.whalebrew? && !args.vscode?

          Homebrew::Bundle::Commands::List.run(
            global: global,
            file: file,
            all: args.all?,
            casks: args.casks?,
            taps: args.taps?,
            mas: args.mas?,
            whalebrew: args.whalebrew?,
            vscode: args.vscode?,
            brews: args.brews? || (no_type_args && !args.all?)
          )
        end
      end

      # Edit subcommand
      class Edit < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle edit`

            Edit the `Brewfile` in your editor.
          EOS
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/brewfile"

          global = args.global?
          file = args.file

          exec_editor(Homebrew::Bundle::Brewfile.path(global: global, file: file))
        end
      end

      # Exec subcommand
      class Exec < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle exec` <command>

            Run an external command in an isolated build environment based on the `Brewfile` dependencies.
          EOS

          switch "--services",
                 description: "Temporarily start services while running the command."

          named_args.unlimited
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/exec"

          global = args.global?
          file = args.file
          services = args.services?
          named_args = args.named

          Homebrew::Bundle::Commands::Exec.run(
            global: global,
            file: file,
            named_args: named_args,
            services: services,
            subcommand: :exec
          )
        end
      end

      # Sh subcommand
      class Sh < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle sh`

            Run your shell in a `brew bundle exec` environment.
          EOS

          switch "--services",
                 description: "Temporarily start services while running the shell."
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/exec"

          global = args.global?
          file = args.file
          services = args.services?

          # Display a helpful notice if environment hints are enabled
          unless Homebrew::EnvConfig.no_env_hints?
            ohai <<~EOS
              Your shell has been configured to use a build environment from your `Brewfile`.
              This should help you build stuff.
              Hide these hints with HOMEBREW_NO_ENV_HINTS (see `man brew`).
            EOS
          end

          Homebrew::Bundle::Commands::Exec.run(
            global: global,
            file: file,
            named_args: [],
            services: services,
            subcommand: :sh
          )
        end
      end

      # Env subcommand
      class Env < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle env`

            Print the environment variables that would be set in a `brew bundle exec` environment.
          EOS

          switch "--services",
                 description: "Temporarily start services."
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/exec"

          global = args.global?
          file = args.file
          services = args.services?

          Homebrew::Bundle::Commands::Exec.run(
            global: global,
            file: file,
            named_args: [],
            services: services,
            subcommand: :env
          )
        end
      end

      # Add subcommand
      class Add < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle add` <name> [...]

            Add entries to your `Brewfile`.
          EOS

          switch "--formula", "--brews",
                 description: "Add Homebrew formula dependencies."
          switch "--cask", "--casks",
                 description: "Add Homebrew cask dependencies."
          switch "--tap", "--taps",
                 description: "Add Homebrew tap dependencies."
          switch "--mas",
                 description: "Add Mac App Store dependencies."
          switch "--whalebrew",
                 description: "Add Whalebrew dependencies."
          switch "--vscode",
                 description: "Add VSCode extensions."

          named_args.at_least(1)
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/add"

          global = args.global?
          file = args.file
          verbose = args.verbose?
          named_args = args.named

          # Determine the type of dependency to add
          type = if args.casks?
            :cask
          elsif args.mas?
            :mas
          elsif args.whalebrew?
            :whalebrew
          elsif args.vscode?
            :vscode
          elsif args.taps?
            :tap
          else
            :brew # formula is the default
          end

          Homebrew::Bundle::Commands::Add.run(
            global: global,
            file: file,
            verbose: verbose,
            type: type,
            named_args: named_args
          )
        end
      end

      # Remove subcommand
      class Remove < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle remove` <name> [...]

            Remove entries from your `Brewfile`.
          EOS

          switch "--formula", "--brews",
                 description: "Remove Homebrew formula dependencies."
          switch "--cask", "--casks",
                 description: "Remove Homebrew cask dependencies."
          switch "--tap", "--taps",
                 description: "Remove Homebrew tap dependencies."
          switch "--mas",
                 description: "Remove Mac App Store dependencies."
          switch "--whalebrew",
                 description: "Remove Whalebrew dependencies."
          switch "--vscode",
                 description: "Remove VSCode extensions."

          named_args.at_least(1)
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/remove"

          global = args.global?
          file = args.file
          verbose = args.verbose?
          named_args = args.named

          # Determine the type of dependency to remove
          type = if args.casks?
            :cask
          elsif args.mas?
            :mas
          elsif args.whalebrew?
            :whalebrew
          elsif args.vscode?
            :vscode
          elsif args.taps?
            :tap
          elsif args.brews?
            :brew
          end

          Homebrew::Bundle::Commands::Remove.run(
            global: global,
            file: file,
            verbose: verbose,
            type: type,
            named_args: named_args
          )
        end
      end

      # Upgrade subcommand
      class Upgrade < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `bundle upgrade`

            Upgrade outdated dependencies from the Brewfile.
            This is a shorthand for `brew bundle install --upgrade`.
          EOS
        end

        sig { override.void }
        def run
          require "bundle"
          require "bundle/commands/install"

          global = args.global?
          file = args.file
          verbose = args.verbose?
          force = args.force?

          # Run the install command with upgrade enabled
          Homebrew::Bundle::Commands::Install.run(
            global: global,
            file: file,
            no_upgrade: false,
            verbose: verbose,
            force: force,
            quiet: !verbose
          )
        end
      end
    end
  end
end

# Special case hook for the main bundle command
# This will be called by the command dispatcher when `brew bundle` is run
module Homebrew
  module_function

  def bundle_new_args
    Cmd::BundleNew.new.args
  end

  def bundle_new
    Cmd::BundleNew.new.run
  end
end
