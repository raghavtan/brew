# typed: strict
# frozen_string_literal: true

require "cli/parser"

module Homebrew
  module_function

  def bundle_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `bundle` [<subcommand>]

        Bundler for non-Ruby dependencies from Homebrew, Homebrew Cask, Mac App Store, Whalebrew and Visual Studio Code.

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
      # Feature flag for selecting between implementations
      switch "--new-system",
             description: "Use the new subcommand system implementation."

      named_args %w[install dump cleanup check exec list sh env edit add remove]
    end
  end

  def bundle
    # Check if the --new-system flag is passed or the environment variable is set
    if ARGV.include?("--new-system") || ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"]
      # Use the new implementation
      require_relative "bundle_new"
      bundle_new
    else
      # Use the original implementation
      args = bundle_args.parse

      # Keep this inside to make `brew` command run faster when no subcommands are used.
      require "bundle"

      subcommand = args.named.first.presence
      if %w[exec add remove].exclude?(subcommand) && args.named.size > 1
        raise UsageError, "This command does not take more than 1 subcommand argument."
      end

      global = args.global?
      file = args.file
      args.zap?
      no_upgrade = if args.upgrade? || subcommand == "upgrade"
        false
      else
        args.no_upgrade?
      end
      verbose = args.verbose?
      force = args.force?
      zap = args.zap?
      Homebrew::Bundle.upgrade_formulae = args.upgrade_formulae

      no_type_args = !args.brews? && !args.casks? && !args.taps? && !args.mas? && !args.whalebrew? && !args.vscode?

      if args.install?
        if [nil, "install", "upgrade"].include?(subcommand)
          raise UsageError, "`--install` cannot be used with `install`, `upgrade` or no subcommand."
        end

        require "bundle/commands/install"
        redirect_stdout($stderr) do
          Homebrew::Bundle::Commands::Install.run(global:, file:, no_upgrade:, verbose:, force:, quiet: true)
        end
      end

      case subcommand
      when nil, "install", "upgrade"
        require "bundle/commands/install"
        Homebrew::Bundle::Commands::Install.run(global:, file:, no_upgrade:, verbose:, force:, quiet: args.quiet?)

        cleanup = if ENV.fetch("HOMEBREW_BUNDLE_INSTALL_CLEANUP", nil)
          args.global?
        else
          args.cleanup?
        end

        if cleanup
          require "bundle/commands/cleanup"
          Homebrew::Bundle::Commands::Cleanup.run(
            global:, file:, zap:,
            force:  true,
            dsl:    Homebrew::Bundle::Commands::Install.dsl
          )
        end
      when "dump"
        vscode = if args.no_vscode?
          false
        elsif args.vscode?
          true
        else
          no_type_args
        end

        require "bundle/commands/dump"
        Homebrew::Bundle::Commands::Dump.run(
          global:, file:, force:,
          describe:   args.describe?,
          no_restart: args.no_restart?,
          taps:       args.taps? || no_type_args,
          brews:      args.brews? || no_type_args,
          casks:      args.casks? || no_type_args,
          mas:        args.mas? || no_type_args,
          whalebrew:  args.whalebrew? || no_type_args,
          vscode:
        )
      when "edit"
        require "bundle/brewfile"
        exec_editor(Homebrew::Bundle::Brewfile.path(global:, file:))
      when "cleanup"
        require "bundle/commands/cleanup"
        Homebrew::Bundle::Commands::Cleanup.run(global:, file:, force:, zap:)
      when "check"
        require "bundle/commands/check"
        Homebrew::Bundle::Commands::Check.run(global:, file:, no_upgrade:, verbose:)
      when "exec", "sh", "env"
        named_args = case subcommand
        when "exec"
          _subcommand, *named_args = args.named
          named_args
        when "sh"
          preferred_path = Utils::Shell.preferred_path(default: "/bin/bash")
          notice = unless Homebrew::EnvConfig.no_env_hints?
            <<~EOS
              Your shell has been configured to use a build environment from your `Brewfile`.
              This should help you build stuff.
              Hide these hints with HOMEBREW_NO_ENV_HINTS (see `man brew`).
            EOS
          end

          []
        else # "env"
          []
        end

        services = args.services?
        require "bundle/commands/exec"
        Homebrew::Bundle::Commands::Exec.run(global:, file:, named_args:, services:, subcommand: subcommand.to_sym)
      when "list"
        require "bundle/commands/list"
        Homebrew::Bundle::Commands::List.run(
          global:, file:,
          all:       args.all?,
          casks:     args.casks?,
          taps:      args.taps?,
          mas:       args.mas?,
          whalebrew: args.whalebrew?,
          vscode:    args.vscode?,
          brews:     args.brews? || (no_type_args && !args.all?)
        )
      when "add", "remove"
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

        _subcommand, *named_args = args.named
        case subcommand
        when "add"
          require "bundle/commands/add"
          Homebrew::Bundle::Commands::Add.run(
            global:, file:, verbose:,
            type:, named_args:
          )
        when "remove"
          require "bundle/commands/remove"
          Homebrew::Bundle::Commands::Remove.run(
            global:, file:, verbose:,
            type:, named_args:
          )
        end
      else
        raise UsageError, "unknown subcommand: #{subcommand}"
      end
    end
  end
end
