# typed: strict
# frozen_string_literal: true

require "subcommand_framework"

module Homebrew
  # Example implementation of the SubcommandBundle module for handling `brew bundle` commands
  # This demonstrates how to use the SubcommandFramework to implement a command with subcommands
  module SubcommandBundle
    include Homebrew::SubcommandFramework

    COMMAND_NAME = "bundle"
    DEFAULT_SUBCOMMAND = "install"

    # Global options applicable to all subcommands
    GLOBAL_OPTIONS = {
      "--file=" => "Read from or write to the `Brewfile` from this location. Use `--file=-` to pipe to stdin/stdout.",
      "--global" => "Read from or write to the `Brewfile` from `$HOMEBREW_BUNDLE_FILE_GLOBAL` (if set), " \
                    "`${XDG_CONFIG_HOME}/homebrew/Brewfile` (if `$XDG_CONFIG_HOME` is set), " \
                    "`~/.homebrew/Brewfile` or `~/.Brewfile` otherwise.",
    }.freeze

    # Definition of each subcommand, its description, and arguments
    SUBCOMMANDS = {
      "install" => {
        description: "Install and upgrade (by default) all dependencies from the `Brewfile`.",
        usage_banner: "",
        args: [
          [:switch, "-v", "--verbose", {
            description: "`install` prints output from commands as they are run."
          }],
          [:switch, "--no-upgrade", {
            env: :bundle_no_upgrade,
            description: "`install` does not run `brew upgrade` on outdated dependencies. " \
                         "Note they may still be upgraded by `brew install` if needed. " \
                         "This is enabled by default if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          }],
          [:switch, "--upgrade", {
            description: "`install` runs `brew upgrade` on outdated dependencies, " \
                         "even if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          }],
          [:flag, "--upgrade-formulae=", "--upgrade-formula=", {
            description: "`install` runs `brew upgrade` on any of these comma-separated formulae, " \
                         "even if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          }],
          [:switch, "-f", "--force", {
            description: "`install` runs with `--force`/`--overwrite`."
          }],
          [:switch, "--cleanup", {
            env: :bundle_install_cleanup,
            description: "`install` performs cleanup operation, same as running `cleanup --force`. " \
                         "This is enabled by default if `$HOMEBREW_BUNDLE_INSTALL_CLEANUP` is set and " \
                         "`--global` is passed."
          }],
        ],
      },
      "dump" => {
        description: "Write all installed casks/formulae/images/taps into a `Brewfile` in the current directory " \
                     "or to a custom file specified with the `--file` option.",
        args: [
          [:switch, "-f", "--force", {
            description: "`dump` overwrites an existing `Brewfile`."
          }],
          [:switch, "--describe", {
            env: :bundle_dump_describe,
            description: "`dump` adds a description comment above each line, unless the " \
                         "dependency does not have a description. " \
                         "This is enabled by default if `$HOMEBREW_BUNDLE_DUMP_DESCRIBE` is set."
          }],
          [:switch, "--no-restart", {
            description: "`dump` does not add `restart_service` to formula lines."
          }],
          [:switch, "--formula", "--brews", {
            description: "`dump` Homebrew formula dependencies."
          }],
          [:switch, "--cask", "--casks", {
            description: "`dump` Homebrew cask dependencies."
          }],
          [:switch, "--tap", "--taps", {
            description: "`dump` Homebrew tap dependencies."
          }],
          [:switch, "--mas", {
            description: "`dump` Mac App Store dependencies."
          }],
          [:switch, "--whalebrew", {
            description: "`dump` Whalebrew dependencies."
          }],
          [:switch, "--vscode", {
            description: "`dump` VSCode (and forks/variants) extensions."
          }],
          [:switch, "--no-vscode", {
            env: :bundle_dump_no_vscode,
            description: "`dump` without VSCode (and forks/variants) extensions. " \
                         "This is enabled by default if `$HOMEBREW_BUNDLE_DUMP_NO_VSCODE` is set."
          }],
        ],
      },
      "cleanup" => {
        description: "Uninstall all dependencies not present in the `Brewfile`.",
        args: [
          [:switch, "-f", "--force", {
            description: "`cleanup` actually performs its cleanup operations."
          }],
          [:switch, "--zap", {
            description: "`cleanup` casks using the `zap` command instead of `uninstall`."
          }],
        ],
      },
      "check" => {
        description: "Check if all dependencies present in the `Brewfile` are installed.",
        args: [
          [:switch, "-v", "--verbose", {
            description: "`check` lists all missing dependencies."
          }],
          [:switch, "--no-upgrade", {
            env: :bundle_no_upgrade,
            description: "`check` does not check for outdated dependencies. " \
                         "This is enabled by default if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
          }],
        ],
      },
      "exec" => {
        description: "Run an external command in an isolated build environment based on the `Brewfile` dependencies.",
        args: [
          [:switch, "--install", {
            description: "Run `install` before continuing to the `exec` command."
          }],
          [:switch, "--services", {
            description: "Temporarily start services while running the `exec` command."
          }],
        ],
      },
      "list" => {
        description: "List all dependencies present in the `Brewfile`.",
        args: [
          [:switch, "--all", {
            description: "`list` all dependencies."
          }],
          [:switch, "--formula", "--brews", {
            description: "`list` Homebrew formula dependencies."
          }],
          [:switch, "--cask", "--casks", {
            description: "`list` Homebrew cask dependencies."
          }],
          [:switch, "--tap", "--taps", {
            description: "`list` Homebrew tap dependencies."
          }],
          [:switch, "--mas", {
            description: "`list` Mac App Store dependencies."
          }],
          [:switch, "--whalebrew", {
            description: "`list` Whalebrew dependencies."
          }],
          [:switch, "--vscode", {
            description: "`list` VSCode (and forks/variants) extensions."
          }],
        ],
      },
      "sh" => {
        description: "Run your shell in a `brew bundle exec` environment.",
        args: [
          [:switch, "--install", {
            description: "Run `install` before continuing to the `sh` command."
          }],
          [:switch, "--services", {
            description: "Temporarily start services while running the `sh` command."
          }],
        ],
      },
      "env" => {
        description: "Print the environment variables that would be set in a `brew bundle exec` environment.",
      },
      "edit" => {
        description: "Edit the `Brewfile` in your editor.",
      },
      "add" => {
        description: "Add entries to your `Brewfile`. Adds formulae by default.",
        args: [
          [:switch, "--cask", "--casks", {
            description: "Add a cask entry to the Brewfile."
          }],
          [:switch, "--tap", "--taps", {
            description: "Add a tap entry to the Brewfile."
          }],
          [:switch, "--whalebrew", {
            description: "Add a whalebrew entry to the Brewfile."
          }],
          [:switch, "--vscode", {
            description: "Add a vscode extension entry to the Brewfile."
          }],
        ],
      },
      "remove" => {
        description: "Remove entries that match `name` from your `Brewfile`.",
        args: [
          [:switch, "--formula", "--brews", {
            description: "Remove formula entries from the Brewfile."
          }],
          [:switch, "--cask", "--casks", {
            description: "Remove cask entries from the Brewfile."
          }],
          [:switch, "--tap", "--taps", {
            description: "Remove tap entries from the Brewfile."
          }],
          [:switch, "--mas", {
            description: "Remove Mac App Store entries from the Brewfile."
          }],
          [:switch, "--whalebrew", {
            description: "Remove whalebrew entries from the Brewfile."
          }],
          [:switch, "--vscode", {
            description: "Remove VSCode extension entries from the Brewfile."
          }],
        ],
      },
    }.freeze

    class << self
      extend T::Sig

      # Example implementation of the install subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def install(args)
        # In a real implementation, this would call the actual bundle install logic
        puts "Would run bundle install with args: #{args.inspect}"
      end

      # Example implementation of the dump subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def dump(args)
        puts "Would run bundle dump with args: #{args.inspect}"
      end

      # Example implementation of the cleanup subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def cleanup(args)
        puts "Would run bundle cleanup with args: #{args.inspect}"
      end

      # Example implementation of the check subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def check(args)
        puts "Would run bundle check with args: #{args.inspect}"
      end

      # Example implementation of the exec subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def exec(args)
        puts "Would run bundle exec with args: #{args.inspect}"
      end

      # Example implementation of the list subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def list(args)
        puts "Would run bundle list with args: #{args.inspect}"
      end

      # Example implementation of the sh subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def sh(args)
        puts "Would run bundle sh with args: #{args.inspect}"
      end

      # Example implementation of the env subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def env(args)
        puts "Would run bundle env with args: #{args.inspect}"
      end

      # Example implementation of the edit subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def edit(args)
        puts "Would run bundle edit with args: #{args.inspect}"
      end

      # Example implementation of the add subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def add(args)
        puts "Would run bundle add with args: #{args.inspect}"
      end

      # Example implementation of the remove subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def remove(args)
        puts "Would run bundle remove with args: #{args.inspect}"
      end
    end
  end
end
