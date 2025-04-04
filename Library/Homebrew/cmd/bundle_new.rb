# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "abstract_subcommand"
require "subcommand_parser"
require "command_options"

module Homebrew
  module Cmd
    class BundleNew < AbstractCommand
      include AbstractSubcommandable
      include SubcommandDispatcher

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

      sig { override.void }
      def run
        require "bundle"

        subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args.remaining_args, self)

        if subcommand_name.nil?
          dispatch_subcommand("install", remaining_args) || raise(UsageError, "No subcommand specified.")
          return
        end

        unless dispatch_subcommand(subcommand_name, remaining_args)
          raise UsageError, "Unknown subcommand: #{subcommand_name}"
        end
      end

      # Base class for bundle subcommands with common setup
      class BundleBaseSubcommand < AbstractSubcommand
        private

        # Get common bundle options
        sig { returns(CommandOptions) }
        def bundle_options
          CommandOptions.new(args)
        end
      end
    end
  end
end

module Homebrew
  module Cmd
    class BundleNew
      class Install < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle install`"

          switch "--no-upgrade",
                 env: :bundle_no_upgrade,
                 description: "Don't run `brew upgrade` on outdated dependencies."
          switch "--upgrade",
                 description: "Run `brew upgrade` even if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          flag "--upgrade-formulae=", "--upgrade-formula=",
               description: "Run `brew upgrade` on these comma-separated formulae."
          switch "-f", "--force",
                 description: "Run `install` with `--force`/`--overwrite`."
          switch "--cleanup",
                 env: :bundle_install_cleanup,
                 description: "Run cleanup after installation."
        end

        sig { override.void }
        def run
          require "bundle/commands/install"
          options = bundle_options

          no_upgrade = args.upgrade? ? false : args.no_upgrade?
          cleanup = args.cleanup?

          Homebrew::Bundle.upgrade_formulae = args.upgrade_formulae

          Homebrew::Bundle::Commands::Install.run(
            global: options.global,
            file: options.file,
            no_upgrade: no_upgrade,
            verbose: options.verbose,
            force: options.force,
            quiet: !options.verbose
          )

          if cleanup
            require "bundle/commands/cleanup"
            Homebrew::Bundle::Commands::Cleanup.run(
              global: options.global,
              file: options.file,
              force: true,
              zap: false,
              dsl: Homebrew::Bundle::Commands::Install.dsl
            )
          end
        end
      end

      class Dump < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle dump`"

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
          require "bundle/commands/dump"
          options = bundle_options
          no_type_args = !args.brews? && !args.casks? && !args.taps? && !args.mas? && !args.whalebrew? && !args.vscode?

          vscode = if args.no_vscode?
                     false
                   elsif args.vscode?
                     true
                   else
                     no_type_args
                   end

          Homebrew::Bundle::Commands::Dump.run(
            global: options.global,
            file: options.file,
            force: options.force,
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

      class Cleanup < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle cleanup`"

          switch "-f", "--force",
                 description: "Actually perform the cleanup operations."
          switch "--zap",
                 description: "Clean up casks using the `zap` command instead of `uninstall`."
        end

        sig { override.void }
        def run
          require "bundle/commands/cleanup"
          options = bundle_options

          Homebrew::Bundle::Commands::Cleanup.run(
            global: options.global,
            file: options.file,
            force: options.force,
            zap: options.zap
          )
        end
      end

      class Check < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle check`"

          switch "--no-upgrade",
                 env: :bundle_no_upgrade,
                 description: "Don't check for outdated dependencies."
        end

        sig { override.void }
        def run
          require "bundle/commands/check"
          options = bundle_options

          Homebrew::Bundle::Commands::Check.run(
            global: options.global,
            file: options.file,
            no_upgrade: args.no_upgrade?,
            verbose: options.verbose
          )
        end
      end

      class List < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle list`"

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
          require "bundle/commands/list"
          options = bundle_options
          no_type_args = !args.brews? && !args.casks? && !args.taps? && !args.mas? && !args.whalebrew? && !args.vscode?

          Homebrew::Bundle::Commands::List.run(
            global: options.global,
            file: options.file,
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

      class Edit < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle edit`"
        end

        sig { override.void }
        def run
          require "bundle/brewfile"
          options = bundle_options
          exec_editor(Homebrew::Bundle::Brewfile.path(global: options.global, file: options.file))
        end
      end

      class Exec < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle exec` <command>"
          switch "--services",
                 description: "Temporarily start services while running the command."
          named_args.unlimited
        end

        sig { override.void }
        def run
          require "bundle/commands/exec"
          options = bundle_options

          Homebrew::Bundle::Commands::Exec.run(
            global: options.global,
            file: options.file,
            named_args: args.named,
            services: args.services?,
            subcommand: :exec
          )
        end
      end

      class Sh < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle sh`"
          switch "--services",
                 description: "Temporarily start services while running the shell."
        end

        sig { override.void }
        def run
          require "bundle/commands/exec"
          options = bundle_options

          unless Homebrew::EnvConfig.no_env_hints?
            ohai <<~EOS
              Your shell has been configured to use a build environment from your `Brewfile`.
              This should help you build stuff.
              Hide these hints with HOMEBREW_NO_ENV_HINTS (see `man brew`).
            EOS
          end

          Homebrew::Bundle::Commands::Exec.run(
            global: options.global,
            file: options.file,
            named_args: [],
            services: args.services?,
            subcommand: :sh
          )
        end
      end

      class Env < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle env`"
          switch "--services",
                 description: "Temporarily start services."
        end

        sig { override.void }
        def run
          require "bundle/commands/exec"
          options = bundle_options

          Homebrew::Bundle::Commands::Exec.run(
            global: options.global,
            file: options.file,
            named_args: [],
            services: args.services?,
            subcommand: :env
          )
        end
      end

      class Add < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle add` <name> [...]"

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
          require "bundle/commands/add"
          options = bundle_options

          type = determine_package_type

          Homebrew::Bundle::Commands::Add.run(
            global: options.global,
            file: options.file,
            verbose: options.verbose,
            type: type,
            named_args: args.named
          )
        end

        private

        # Determine the package type based on arguments
        sig { returns(Symbol) }
        def determine_package_type
          if args.casks?
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
            :brew
          end
        end
      end

      class Remove < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle remove` <name> [...]"

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
          require "bundle/commands/remove"
          options = bundle_options

          type = determine_package_type

          Homebrew::Bundle::Commands::Remove.run(
            global: options.global,
            file: options.file,
            verbose: options.verbose,
            type: type,
            named_args: args.named
          )
        end

        private

        # Determine the package type based on arguments
        sig { returns(T.nilable(Symbol)) }
        def determine_package_type
          if args.casks?
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
          else
            nil
          end
        end
      end

      class Upgrade < BundleBaseSubcommand
        cmd_args do
          usage_banner "`bundle upgrade`"
        end

        sig { override.void }
        def run
          require "bundle/commands/install"
          options = bundle_options

          Homebrew::Bundle::Commands::Install.run(
            global: options.global,
            file: options.file,
            no_upgrade: false,
            verbose: options.verbose,
            force: options.force,
            quiet: !options.verbose
          )
        end
      end
    end
  end
end

module Homebrew
  module_function

  def bundle_new_args
    Cmd::BundleNew.new.args
  end

  def bundle_new
    Cmd::BundleNew.new.run
  end
end
