# typed: true
# frozen_string_literal: true

require "abstract_command"
require "abstract_subcommand"
require "subcommand_parser"
require "services"
require "services/system"
require "command_options"

module Homebrew
  module Cmd
    class ServicesNew < AbstractCommand
      include AbstractSubcommandable
      include SubcommandDispatcher

      shared_args do
        usage_banner <<~EOS
          `services` [<subcommand>]

          Manage background services with macOS' `launchctl`(1) daemon manager or
          Linux's `systemctl`(1) service manager.
        EOS

        flag "--sudo-service-user=",
             description: "When run as root on macOS, run the service(s) as this user."
        switch "--json",
               description: "Output as JSON."
        switch "--all",
               description: "Run <subcommand> on all services."
      end

      sig { override.void }
      def run
        # Check for tmux compatibility
        if ENV.fetch("HOMEBREW_TMUX", nil) && File.exist?("/usr/bin/pbpaste") && !quiet_system("/usr/bin/pbpaste")
          raise UsageError, "`brew services` cannot run under tmux!"
        end

        # Validate system requirements
        if !Services::System.launchctl? && !Services::System.systemctl?
          raise UsageError, "`brew services` is supported only on macOS or Linux (with systemd)!"
        end

        # Handle sudo service user
        setup_sudo_service_user

        # Setup systemd environment variables if needed
        setup_systemd_environment if Services::System.systemctl?

        # Parse and dispatch subcommand
        subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args.remaining_args, self)

        if subcommand_name.nil?
          dispatch_subcommand("list", remaining_args) || raise(UsageError, "No subcommand specified.")
          return
        end

        unless dispatch_subcommand(subcommand_name, remaining_args)
          raise UsageError, "Unknown subcommand: #{subcommand_name}"
        end
      end

      private

      def setup_sudo_service_user
        return unless (sudo_service_user = args.sudo_service_user)

        unless Services::System.root?
          raise UsageError, "`brew services` is supported only when running as root!"
        end

        unless Services::System.launchctl?
          raise UsageError,
                "`brew services --sudo-service-user` is currently supported only on macOS!"
        end

        Services::Cli.sudo_service_user = sudo_service_user
      end

      def setup_systemd_environment
        ENV["DBUS_SESSION_BUS_ADDRESS"] = ENV.fetch("HOMEBREW_DBUS_SESSION_BUS_ADDRESS", nil)
        ENV["XDG_RUNTIME_DIR"] = ENV.fetch("HOMEBREW_XDG_RUNTIME_DIR", nil)
      end
    end
  end
end

module Homebrew
  module Cmd
    class ServicesNew
      # Base class for services subcommands that need to work with targets
      class TargetableSubcommand < AbstractSubcommand
        include TargetableCommand

        private

        # Check if all targets is empty and return early if true
        sig { params(targets: T::Array[T.untyped]).returns(T::Boolean) }
        def check_empty_targets(targets)
          return false unless args.all? && targets.empty?
          true
        end
      end

      class List < AbstractSubcommand
        cmd_args do
          usage_banner "`services list` (`--json`)"
        end

        sig { override.void }
        def run
          require "services/commands/list"
          Services::Commands::List.run(json: args.json?)
        end
      end

      class Info < AbstractSubcommand
        cmd_args do
          usage_banner "`services info` (<formula>|`--all`|`--json`)"
        end

        sig { override.void }
        def run
          require "services/commands/info"
          targets = args.named_args.present? ? args.named_args.map { |f| Services::FormulaWrapper.new(Formulary.factory(f)) } : []
          Services::Commands::Info.run(targets: targets, verbose: args.verbose?, json: args.json?)
        end
      end

      class Run < TargetableSubcommand
        cmd_args do
          usage_banner "`services run` (<formula>|`--all`|`--file=`)"
          flag "--file=", description: "Use the service file from this location"
          flag "--max-wait=", description: "Wait this many seconds for service to start"
          switch "--no-wait", description: "Don't wait for service to start"
        end

        sig { override.void }
        def run
          require "services/commands/run"
          options = CommandOptions.new(args)
          wait = args.no_wait? ? false : (args.max_wait.to_f.positive? ? args.max_wait.to_f : true)

          if args.file.present?
            Services::Commands::Run.run(file: args.file, wait: wait, verbose: options.verbose)
            return
          end

          targets = get_targets(loaded: false)
          return if check_empty_targets(targets)
          Services::Commands::Run.run(targets: targets, wait: wait, verbose: options.verbose)
        end
      end

      class Start < TargetableSubcommand
        cmd_args do
          usage_banner "`services start` (<formula>|`--all`|`--file=`)"
          flag "--file=", description: "Use the service file from this location"
        end

        sig { override.void }
        def run
          require "services/commands/start"
          options = CommandOptions.new(args)

          if args.file.present?
            Services::Commands::Start.run([], args.file, verbose: options.verbose)
            return
          end

          targets = get_targets(loaded: false)
          return if check_empty_targets(targets)
          Services::Commands::Start.run(targets, nil, verbose: options.verbose)
        end
      end

      class Stop < TargetableSubcommand
        cmd_args do
          usage_banner "`services stop` (<formula>|`--all`)"
          flag "--max-wait=", description: "Wait this many seconds for service to stop"
          switch "--no-wait", description: "Don't wait for service to stop"
          switch "--keep", description: "Keep the service registered"
        end

        sig { override.void }
        def run
          require "services/commands/stop"
          options = CommandOptions.new(args)

          targets = get_targets(loaded: true)
          return if check_empty_targets(targets)

          Services::Commands::Stop.run(
            targets,
            verbose: options.verbose,
            no_wait: options.no_wait,
            max_wait: options.max_wait,
            keep: options.keep
          )
        end
      end

      class Kill < TargetableSubcommand
        cmd_args do
          usage_banner "`services kill` (<formula>|`--all`)"
        end

        sig { override.void }
        def run
          require "services/commands/kill"
          options = CommandOptions.new(args)

          targets = get_targets(loaded: true)
          return if check_empty_targets(targets)
          Services::Commands::Kill.run(targets: targets, verbose: options.verbose)
        end
      end

      class Restart < TargetableSubcommand
        cmd_args do
          usage_banner "`services restart` (<formula>|`--all`)"
          flag "--max-wait=", description: "Wait this many seconds for service to stop/start"
          switch "--no-wait", description: "Don't wait for service to stop/start"
        end

        sig { override.void }
        def run
          require "services/commands/restart"
          options = CommandOptions.new(args)

          targets = get_targets(loaded: true)
          return if check_empty_targets(targets)

          Services::Commands::Restart.run(
            targets,
            verbose: options.verbose,
            no_wait: options.no_wait,
            max_wait: options.max_wait
          )
        end
      end

      class Cleanup < AbstractSubcommand
        cmd_args do
          usage_banner "`services cleanup`"
        end

        sig { override.void }
        def run
          require "services/commands/cleanup"
          options = CommandOptions.new(args)
          Services::Commands::Cleanup.run(verbose: options.verbose)
        end
      end
    end
  end
end

module Homebrew
  module_function

  def services_new_args
    Cmd::ServicesNew.new.args
  end

  def services_new
    Cmd::ServicesNew.new.run
  end
end
