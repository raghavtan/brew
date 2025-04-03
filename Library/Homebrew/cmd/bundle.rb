# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "subcommand_framework"
require "subcommand_bundle"

module Homebrew
  module Cmd
    class Bundle < AbstractCommand
      cmd_args do
        usage_banner <<~EOS
          `bundle` [<subcommand>]

          Bundler for non-Ruby dependencies from Homebrew, Homebrew Cask, Mac App Store, Whalebrew and Visual Studio Code (and forks/variants).

          `brew bundle` [`install`]:
          Install and upgrade (by default) all dependencies from the `Brewfile`.

          You can specify the `Brewfile` location using `--file` or by setting the `$HOMEBREW_BUNDLE_FILE` environment variable.

          You can skip the installation of dependencies by adding space-separated values to one or more of the following environment variables: `$HOMEBREW_BUNDLE_BREW_SKIP`, `$HOMEBREW_BUNDLE_CASK_SKIP`, `$HOMEBREW_BUNDLE_MAS_SKIP`, `$HOMEBREW_BUNDLE_WHALEBREW_SKIP`, `$HOMEBREW_BUNDLE_TAP_SKIP`.

          `brew bundle upgrade`:
          Shorthand for `brew bundle install --upgrade`.

          `brew bundle dump`:
          Write all installed casks/formulae/images/taps into a `Brewfile` in the current directory or to a custom file specified with the `--file` option.

          `brew bundle cleanup`:
          Uninstall all dependencies not present in the `Brewfile`.

          This workflow is useful for maintainers or testers who regularly install lots of formulae.

          Unless `--force` is passed, this returns a 1 exit code if anything would be removed.

          `brew bundle check`:
          Check if all dependencies present in the `Brewfile` are installed.

          This provides a successful exit code if everything is up-to-date, making it useful for scripting.

          `brew bundle list`:
          List all dependencies present in the `Brewfile`.

          By default, only Homebrew formula dependencies are listed.

          `brew bundle edit`:
          Edit the `Brewfile` in your editor.

          `brew bundle add` <n> [...]:
          Add entries to your `Brewfile`. Adds formulae by default. Use `--cask`, `--tap`, `--whalebrew` or `--vscode` to add the corresponding entry instead.

          `brew bundle remove` <n> [...]:
          Remove entries that match `name` from your `Brewfile`. Use `--formula`, `--cask`, `--tap`, `--mas`, `--whalebrew` or `--vscode` to remove only entries of the corresponding type. Passing `--formula` also removes matches against formula aliases and old formula names.

          `brew bundle exec` <command>:
          Run an external command in an isolated build environment based on the `Brewfile` dependencies.

          This sanitized build environment ignores unrequested dependencies, which makes sure that things you didn't specify in your `Brewfile` won't get picked up by commands like `bundle install`, `npm install`, etc. It will also add compiler flags which will help with finding keg-only dependencies like `openssl`, `icu4c`, etc.

          `brew bundle sh`:
          Run your shell in a `brew bundle exec` environment.

          `brew bundle env`:
          Print the environment variables that would be set in a `brew bundle exec` environment.
        EOS
        # Global options
        flag "--file=",
             description: "Read from or write to the `Brewfile` from this location. " \
                          "Use `--file=-` to pipe to stdin/stdout."
        switch "--global",
               description: "Read from or write to the `Brewfile` from `$HOMEBREW_BUNDLE_FILE_GLOBAL` (if set), " \
                            "`${XDG_CONFIG_HOME}/homebrew/Brewfile` (if `$XDG_CONFIG_HOME` is set), " \
                            "`~/.homebrew/Brewfile` or `~/.Brewfile` otherwise."
        switch "-v", "--verbose",
               description: "`install` prints output from commands as they are run. " \
                            "`check` lists all missing dependencies."
        switch "--no-upgrade",
               env:         :bundle_no_upgrade,
               description: "`install` does not run `brew upgrade` on outdated dependencies. " \
                            "`check` does not check for outdated dependencies. " \
                            "Note they may still be upgraded by `brew install` if needed. " \
                            "This is enabled by default if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
        switch "--upgrade",
               description: "`install` runs `brew upgrade` on outdated dependencies, " \
                            "even if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
        flag "--upgrade-formulae=", "--upgrade-formula=",
             description: "`install` runs `brew upgrade` on any of these comma-separated formulae, " \
                          "even if `$HOMEBREW_BUNDLE_NO_UPGRADE` is set."
        switch "--install",
               description: "Run `install` before continuing to other operations e.g. `exec`."
        switch "--services",
               description: "Temporarily start services while running the `exec` or `sh` command."
        switch "-f", "--force",
               description: "`install` runs with `--force`/`--overwrite`. " \
                            "`dump` overwrites an existing `Brewfile`. " \
                            "`cleanup` actually performs its cleanup operations."
        switch "--cleanup",
               env:         :bundle_install_cleanup,
               description: "`install` performs cleanup operation, same as running `cleanup --force`. " \
                            "This is enabled by default if `$HOMEBREW_BUNDLE_INSTALL_CLEANUP` is set and " \
                            "`--global` is passed."
        switch "--all",
               description: "`list` all dependencies."
        switch "--formula", "--brews",
               description: "`list` or `dump` Homebrew formula dependencies."
        switch "--cask", "--casks",
               description: "`list` or `dump` Homebrew cask dependencies."
        switch "--tap", "--taps",
               description: "`list` or `dump` Homebrew tap dependencies."
        switch "--mas",
               description: "`list` or `dump` Mac App Store dependencies."
        switch "--whalebrew",
               description: "`list` or `dump` Whalebrew dependencies."
        switch "--vscode",
               description: "`list` or `dump` VSCode (and forks/variants) extensions."
        switch "--no-vscode",
               env:         :bundle_dump_no_vscode,
               description: "`dump` without VSCode (and forks/variants) extensions. " \
                            "This is enabled by default if `$HOMEBREW_BUNDLE_DUMP_NO_VSCODE` is set."
        switch "--describe",
               env:         :bundle_dump_describe,
               description: "`dump` adds a description comment above each line, unless the " \
                            "dependency does not have a description. " \
                            "This is enabled by default if `$HOMEBREW_BUNDLE_DUMP_DESCRIBE` is set."
        switch "--no-restart",
               description: "`dump` does not add `restart_service` to formula lines."
        switch "--zap",
               description: "`cleanup` casks using the `zap` command instead of `uninstall`."

        conflicts "--all", "--no-vscode"
        conflicts "--vscode", "--no-vscode"
        conflicts "--install", "--upgrade"

        named_args %w[install dump cleanup check exec list sh env edit add remove]
      end

      sig { override.void }
      def run
        # Keep this inside `run` to keep --help fast.
        # Route the command to our new SubcommandBundle module that implements
        # the SubcommandFramework

        # Map the parsed args to an array of strings to pass to the SubcommandBundle
        # This is a temporary solution until we fully migrate to the new framework
        argv = []

        # Add named args (subcommand and its arguments)
        argv.concat(args.named)

        # Add option flags
        argv << "--file=#{args.file}" if args.file
        argv << "--global" if args.global?
        argv << "--verbose" if args.verbose?
        argv << "--no-upgrade" if args.no_upgrade?
        argv << "--upgrade" if args.upgrade?
        argv << "--upgrade-formulae=#{args.upgrade_formulae}" if args.upgrade_formulae
        argv << "--install" if args.install?
        argv << "--services" if args.services?
        argv << "--force" if args.force?
        argv << "--cleanup" if args.cleanup?
        argv << "--all" if args.all?
        argv << "--formula" if args.brews?
        argv << "--cask" if args.casks?
        argv << "--tap" if args.taps?
        argv << "--mas" if args.mas?
        argv << "--whalebrew" if args.whalebrew?
        argv << "--vscode" if args.vscode?
        argv << "--no-vscode" if args.no_vscode?
        argv << "--describe" if args.describe?
        argv << "--no-restart" if args.no_restart?
        argv << "--zap" if args.zap?

        SubcommandBundle.route_subcommand(argv)
      end
    end
  end
end
