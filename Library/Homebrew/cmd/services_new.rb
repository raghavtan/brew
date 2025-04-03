# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "abstract_subcommand"
require "subcommand_parser"
require "services/system"

module Homebrew
  module Cmd
    class ServicesNew < AbstractCommand
      include AbstractSubcommandableMixin
      include SubcommandDispatchMixin

      # Define shared arguments that apply to all services subcommands
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

      # Define command-level arguments that don't apply to subcommands
      cmd_args do
        # No additional arguments specific to the main command
        # Since all functionality is in subcommands

        named_args %w[list info run start stop kill restart cleanup]
      end

      sig { override.void }
      def run
        # pbpaste's exit status is a proxy for detecting the use of reattach-to-user-namespace
        if ENV.fetch("HOMEBREW_TMUX", nil) && File.exist?("/usr/bin/pbpaste") && !quiet_system("/usr/bin/pbpaste")
          raise UsageError, "`brew services` cannot run under tmux!"
        end

        # Validate service system availability
        if !Homebrew::Services::System.launchctl? && !Homebrew::Services::System.systemctl?
          raise UsageError, "`brew services` is supported only on macOS or Linux (with systemd)!"
        end

        # Handle sudo service user
        if (sudo_service_user = args.sudo_service_user)
          unless Homebrew::Services::System.root?
            raise UsageError, "`brew services` is supported only when running as root!"
          end

          unless Homebrew::Services::System.launchctl?
            raise UsageError,
                  "`brew services --sudo-service-user` is currently supported only on macOS " \
                  "(but we'd love a PR to add Linux support)!"
          end

          Homebrew::Services::Cli.sudo_service_user = sudo_service_user
        end

        # Set environment variables for systemctl if needed
        if Homebrew::Services::System.systemctl?
          ENV["DBUS_SESSION_BUS_ADDRESS"] = ENV.fetch("HOMEBREW_DBUS_SESSION_BUS_ADDRESS", nil)
          ENV["XDG_RUNTIME_DIR"] = ENV.fetch("HOMEBREW_XDG_RUNTIME_DIR", nil)
        end

        # Parse and extract subcommand name and the remaining arguments
        subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args.remaining_args, self)

        # Handle the case where no subcommand is specified
        if subcommand_name.nil?
          # Default to "list" if no subcommand is specified
          dispatch_subcommand("list", remaining_args) || raise(UsageError, "No subcommand specified. Try `brew services list`")
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

# Define the services subcommands as separate classes
module Homebrew
  module Cmd
    class ServicesNew
      # List subcommand
      class List < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services list` (`--json`) (`--debug`)

            List information about all managed services for the current user (or root).
          EOS
        end

        sig { override.void }
        def run
          require "services/commands/list"
          Homebrew::Services::Commands::List.run(json: args.json?)
        end
      end

      # Start subcommand
      class Start < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services start` (<formula>|`--all`|`--file=`)

            Start the service <formula> immediately and register it to launch at login (or boot).
          EOS

          flag "--file=", 
               description: "Use the service file from this location to start the service."
        end

        sig { override.void }
        def run
          require "services/cli"
          require "services/commands/start"
          require "services/formulae"

          # Get the targets
          targets = get_service_targets

          # Exit if there's nothing to do
          return if args.all? && targets.empty?

          # Run the start command
          Homebrew::Services::Commands::Start.run(targets, args.file, verbose: args.verbose?)
        end

        private

        # Get the target services based on user input
        sig { returns(T::Array[Services::FormulaWrapper]) }
        def get_service_targets
          if args.all?
            Homebrew::Services::Formulae.available_services(
              loaded: false,
              skip_root: !Homebrew::Services::System.root?,
            )
          elsif args.remaining_args.present?
            args.remaining_args.map { |formula| Homebrew::Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end
        end
      end

      # Stop subcommand
      class Stop < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services stop` (`--keep`) (`--no-wait`|`--max-wait=`) (<formula>|`--all`)

            Stop the service <formula> immediately and unregister it from launching at login (or boot),
            unless `--keep` is specified.
          EOS

          switch "--keep", 
                 description: "When stopped, don't unregister the service from launching at login (or boot)."
          switch "--no-wait", 
                 description: "Don't wait for stop to finish stopping the service."
          flag "--max-wait=", 
               description: "Wait at most this many seconds for stop to finish stopping a service. " \
                           "Omit this flag or set this to zero (0) seconds to wait indefinitely."

          conflicts "--max-wait=", "--no-wait"
        end

        sig { override.void }
        def run
          require "services/cli"
          require "services/commands/stop"
          require "services/formulae"

          # Get the targets
          targets = get_service_targets

          # Exit if there's nothing to do
          return if args.all? && targets.empty?

          # Run the stop command
          Homebrew::Services::Commands::Stop.run(
            targets,
            verbose: args.verbose?,
            no_wait: args.no_wait?,
            max_wait: args.max_wait.to_f,
            keep: args.keep?,
          )
        end

        private

        # Get the target services based on user input
        sig { returns(T::Array[Services::FormulaWrapper]) }
        def get_service_targets
          if args.all?
            Homebrew::Services::Formulae.available_services(
              loaded: true,
              skip_root: !Homebrew::Services::System.root?,
            )
          elsif args.remaining_args.present?
            args.remaining_args.map { |formula| Homebrew::Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end
        end
      end

      # Register subcommands with their aliases
      register_subcommand(List, ["list", "ls", "l"])
      register_subcommand(Start, ["start", "launch", "load", "s", "l"])
      register_subcommand(Stop, ["stop", "unload", "terminate", "t", "u"])
      
      # Additional subcommands would be defined here...
    end
  end
end