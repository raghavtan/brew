# typed: true
# frozen_string_literal: true

require "cli/parser"
require "services"
require "abstract_command"
require "abstract_subcommand"
require "subcommand_parser"
require "services/system"

module Homebrew
  module Cmd
    class Services < AbstractCommand
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

      # Define command-level arguments for the legacy implementation
      cmd_args do
        usage_banner <<~EOS
          `services` [<subcommand>]

          Manage background services with macOS' `launchctl`(1) daemon manager or
          Linux's `systemctl`(1) service manager.
        EOS

        flag "--sudo-service-user=",
             description: "When run as root on macOS, run the service(s) as this user."
        flag "--file=",
             description: "Use the service file from this location if it exists."
        flag "--max-wait=",
             description: "Wait at most this many seconds for a service to finish stopping " \
                         "before restarting (or starting)."
        switch "--all", description: "Run <subcommand> on all services."
        switch "--no-wait", description: "Don't wait for services to finish stopping."
        switch "--json", description: "Output as JSON."
        switch "--keep", description: "When stopping, don't unload from the system manager."
        # Feature flag for selecting between implementations
        # This flag is now deprecated as the code has been merged
        switch "--new-system", hidden: true, description: "Use the new subcommand system implementation."

        conflicts "--max-wait=", "--no-wait"

        named_args [:subcommand, :formula]
      end

      sig { override.void }
      def run
        args = Homebrew.services_args.parse if defined?(Homebrew.services_args)
        args ||= self.args

        # For backward compatibility, use the legacy implementation
        # when not explicitly requesting the new system
        if args.new_system? || ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"]
          run_new_system
        else
          run_legacy_system
        end
      end

      private

      def run_legacy_system
        args = Homebrew.services_args.parse if defined?(Homebrew.services_args)
        args ||= self.args

        # Original implementation starts here
        if OS.mac? && ENV.fetch("HOMEBREW_TMUX", nil) && File.exist?("/usr/bin/pbpaste") && !quiet_system("/usr/bin/pbpaste")
          raise UsageError, "`brew services` cannot run under tmux!"
        end

        # pbpaste's exit status is a proxy for detecting the use of reattach-to-user-namespace
        if !Services::System.launchctl? && !Services::System.systemctl?
          raise UsageError, "`brew services` is supported only on macOS or Linux (with systemd)!"
        end

        if (sudo_service_user = args.sudo_service_user)
          unless Services::System.root?
            raise UsageError, "`brew services` is supported only when running as root!"
          end

          unless Services::System.launchctl?
            raise UsageError,
                  "`brew services --sudo-service-user` is currently supported only on macOS " \
                  "(but we'd love a PR to add Linux support)!"
          end

          Services::Cli.sudo_service_user = sudo_service_user
        end

        if Services::System.systemctl?
          ENV["DBUS_SESSION_BUS_ADDRESS"] = ENV.fetch("HOMEBREW_DBUS_SESSION_BUS_ADDRESS", nil)
          ENV["XDG_RUNTIME_DIR"] = ENV.fetch("HOMEBREW_XDG_RUNTIME_DIR", nil)
        end

        subcommand = args.named.first
        targets = args.named.drop(1).map { |formula| FormulaWrapper.new(Formulary.factory(formula)) }

        if subcommand.nil?
          # Default to `list` if no subcommand was given
          # (and a non-existent formula wasn't provided)
          subcommand = "list"
        end

        no_wait = args.no_wait?
        max_wait = args.max_wait.to_f

        # Create targets for all available services if `--all` was given
        if args.all? && targets.empty?
          targets =
            if subcommand == "run" || subcommand == "start" || subcommand == "launch" || subcommand == "load"
              Services::Formulae.available_services(loaded: false)
            else
              Services::Formulae.available_services(loaded: true)
            end
        end

        case subcommand
        when "list", "ls", "l"
          Services::Commands::List.run(json: args.json?)
        when "run"
          wait = if no_wait
            false
          elsif max_wait.positive?
            max_wait
          else
            true
          end

          # Default command, no need for a special case
          if args.file.present?
            Services::Commands::Run.run(file: args.file, wait: wait, verbose: args.verbose?)
          elsif targets.present?
            Services::Commands::Run.run(targets: targets, wait: wait, verbose: args.verbose?)
          else
            raise UsageError, "No targets specified. Please provide a service target (formula) or file."
          end
        when "start", "launch", "load", "s", "l"
          Services::Commands::Start.run(targets, args.file, verbose: args.verbose?)
        when "stop", "unload", "terminate", "t", "u"
          Services::Commands::Stop.run(
            targets,
            verbose: args.verbose?,
            no_wait: no_wait,
            max_wait: max_wait,
            keep: args.keep?,
          )
        when "restart", "relaunch", "reload", "r"
          Services::Commands::Restart.run(
            targets,
            verbose: args.verbose?,
            no_wait: no_wait,
            max_wait: max_wait,
          )
        when "kill", "k"
          Services::Commands::Kill.run(targets: targets, verbose: args.verbose?)
        when "info", "i", "--info"
          Services::Commands::Info.run(targets: targets, json: args.json?)
        when "cleanup", "clean", "cl", "c"
          Services::Commands::Cleanup.run(verbose: args.verbose?)
        else
          raise_invalid_subcommand_error!(subcommand)
        end
      end

      def run_new_system
        # pbpaste's exit status is a proxy for detecting the use of reattach-to-user-namespace
        if OS.mac? && ENV.fetch("HOMEBREW_TMUX", nil) && File.exist?("/usr/bin/pbpaste") && !quiet_system("/usr/bin/pbpaste")
          raise UsageError, "`brew services` cannot run under tmux!"
        end

        # Validate service system availability
        if !Services::System.launchctl? && !Services::System.systemctl?
          raise UsageError, "`brew services` is supported only on macOS or Linux (with systemd)!"
        end

        # Handle sudo service user
        if (sudo_service_user = args.sudo_service_user)
          unless Services::System.root?
            raise UsageError, "`brew services` is supported only when running as root!"
          end

          unless Services::System.launchctl?
            raise UsageError,
                  "`brew services --sudo-service-user` is currently supported only on macOS " \
                  "(but we'd love a PR to add Linux support)!"
          end

          Services::Cli.sudo_service_user = sudo_service_user
        end

        # Set environment variables for systemctl if needed
        if Services::System.systemctl?
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

      def raise_invalid_subcommand_error!(subcommand)
        error_message = if !Services::System.launchctl? && !Services::System.systemctl?
          "`brew services` is supported only on macOS or Linux (with systemd)!"
        else
          "`#{subcommand}` is not a valid subcommand!"
        end

        raise UsageError, error_message
      end
    end
  end
end

# Define the services subcommands as separate classes
module Homebrew
  module Cmd
    class Services
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
          Services::Commands::List.run(json: args.json?)
        end
      end

      # Info subcommand
      class Info < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services info` (<formula>|`--all`|`--json`)

            List information about all managed services for the current user (or root).
          EOS
        end

        sig { override.void }
        def run
          require "services/commands/info"

          # Create formula wrappers for each named formula
          targets = if args.named_args.present?
            args.named_args.map { |formula| Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end

          Services::Commands::Info.run(
            targets: targets,
            verbose: args.verbose?,
            json: args.json?
          )
        end
      end

      # Run subcommand
      class Run < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services run` (<formula>|`--all`|`--file=`)

            Run the service <formula> without registering to launch at login (or boot).
          EOS

          flag "--file=",
               description: "Use the service file from this location to run the service."
          flag "--max-wait=",
               description: "Wait at most this many seconds for the service to finish starting. " \
                            "Omit this flag or set this to zero (0) seconds to wait indefinitely."
          switch "--no-wait",
                 description: "Don't wait for the service to finish starting."
        end

        sig { override.void }
        def run
          require "services/commands/run"

          # Determine wait behavior
          wait = if args.no_wait?
            false
          elsif args.max_wait.to_f.positive?
            args.max_wait.to_f
          else
            true
          end

          # File-based run
          if args.file.present?
            Services::Commands::Run.run(
              file: args.file,
              wait: wait,
              verbose: args.verbose?
            )
            return
          end

          # Create formula wrappers for each formula or all formulae
          targets = get_service_targets

          Services::Commands::Run.run(
            targets: targets,
            wait: wait,
            verbose: args.verbose?
          )
        end

        private

        # Get the target services based on user input
        sig { returns(T::Array[Services::FormulaWrapper]) }
        def get_service_targets
          if args.all?
            Services::Formulae.available_services(
              loaded: false,
              skip_root: !Services::System.root?
            )
          elsif args.named_args.present?
            args.named_args.map { |formula| Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end
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

          # If a file is specified, start the service from the file
          if args.file.present?
            Services::Commands::Start.run(
              [],  # No targets when using a file
              args.file,
              verbose: args.verbose?
            )
            return
          end

          # Create formula wrappers for each formula or all formulae
          targets = get_service_targets

          # Exit if there's nothing to do
          return if args.all? && targets.empty?

          # Run the start command
          Services::Commands::Start.run(
            targets,
            nil,  # No file
            verbose: args.verbose?
          )
        end

        private

        # Get the target services based on user input
        sig { returns(T::Array[Services::FormulaWrapper]) }
        def get_service_targets
          if args.all?
            Services::Formulae.available_services(
              loaded: false,
              skip_root: !Services::System.root?
            )
          elsif args.named_args.present?
            args.named_args.map { |formula| Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end
        end
      end

      # Stop subcommand
      class Stop < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services stop` (<formula>|`--all`)

            Stop the service <formula> if it is running.
          EOS

          flag "--max-wait=",
               description: "Wait at most this many seconds for the service to finish stopping."
          switch "--no-wait",
               description: "Don't wait for the service to finish stopping."
          switch "--keep",
               description: "Keep the service unloaded from the service manager but don't stop it."
        end

        sig { override.void }
        def run
          require "services/commands/stop"

          # Create formula wrappers for each formula or all formulae
          targets = get_service_targets

          # Exit if there's nothing to do
          return if args.all? && targets.empty?

          # Determine wait behavior
          no_wait = args.no_wait?
          max_wait = args.max_wait.to_f

          # Run the stop command
          Services::Commands::Stop.run(
            targets,
            verbose: args.verbose?,
            no_wait: no_wait,
            max_wait: max_wait,
            keep: args.keep?
          )
        end

        private

        # Get the target services based on user input
        sig { returns(T::Array[Services::FormulaWrapper]) }
        def get_service_targets
          if args.all?
            Services::Formulae.available_services(
              loaded: true,
              skip_root: !Services::System.root?
            )
          elsif args.named_args.present?
            args.named_args.map { |formula| Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end
        end
      end

      # Kill subcommand
      class Kill < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services kill` (<formula>|`--all`)

            Kill the service <formula> if it is running.
          EOS
        end

        sig { override.void }
        def run
          require "services/commands/kill"

          # Create formula wrappers for each formula or all formulae
          targets = get_service_targets

          # Exit if there's nothing to do
          return if args.all? && targets.empty?

          # Run the kill command
          Services::Commands::Kill.run(
            targets: targets,
            verbose: args.verbose?
          )
        end

        private

        # Get the target services based on user input
        sig { returns(T::Array[Services::FormulaWrapper]) }
        def get_service_targets
          if args.all?
            Services::Formulae.available_services(
              loaded: true,
              skip_root: !Services::System.root?
            )
          elsif args.named_args.present?
            args.named_args.map { |formula| Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end
        end
      end

      # Restart subcommand
      class Restart < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services restart` (<formula>|`--all`)

            Stop (if necessary) and start the service <formula>.
          EOS

          flag "--max-wait=",
               description: "Wait at most this many seconds for a service to finish stopping/starting."
          switch "--no-wait",
               description: "Don't wait for services to finish stopping/starting."
        end

        sig { override.void }
        def run
          require "services/commands/restart"

          # Create formula wrappers for each formula or all formulae
          targets = get_service_targets

          # Exit if there's nothing to do
          return if args.all? && targets.empty?

          # Determine wait behavior
          no_wait = args.no_wait?
          max_wait = args.max_wait.to_f

          # Run the restart command
          Services::Commands::Restart.run(
            targets,
            verbose: args.verbose?,
            no_wait: no_wait,
            max_wait: max_wait
          )
        end

        private

        # Get the target services based on user input
        sig { returns(T::Array[Services::FormulaWrapper]) }
        def get_service_targets
          if args.all?
            Services::Formulae.available_services(
              loaded: true,
              skip_root: !Services::System.root?
            )
          elsif args.named_args.present?
            args.named_args.map { |formula| Services::FormulaWrapper.new(Formulary.factory(formula)) }
          else
            []
          end
        end
      end

      # Cleanup subcommand
      class Cleanup < AbstractSubcommand
        cmd_args do
          usage_banner <<~EOS
            `services cleanup`

            Remove all unused service-related files.
          EOS
        end

        sig { override.void }
        def run
          require "services/commands/cleanup"

          Services::Commands::Cleanup.run(verbose: args.verbose?)
        end
      end
    end
  end
end

# Keep the module_function interface for backward compatibility
module Homebrew
  module_function

  def services_args
    CLI::Parser.new do
      usage_banner <<~EOS
        `services` [<subcommand>]

        Manage background services with macOS' `launchctl`(1) daemon manager or
        Linux's `systemctl`(1) service manager.
      EOS

      flag "--sudo-service-user=",
           description: "When run as root on macOS, run the service(s) as this user."
      flag "--file=",
           description: "Use the service file from this location if it exists."
      flag "--max-wait=",
           description: "Wait at most this many seconds for a service to finish stopping " \
                       "before restarting (or starting)."
      switch "--all", description: "Run <subcommand> on all services."
      switch "--no-wait", description: "Don't wait for services to finish stopping."
      switch "--json", description: "Output as JSON."
      switch "--keep", description: "When stopping, don't unload from the system manager."
      # Feature flag for selecting between implementations
      # This flag is now deprecated as the code has been merged
      switch "--new-system", hidden: true, description: "Use the new subcommand system implementation."

      conflicts "--max-wait=", "--no-wait"

      named_args [:subcommand, :formula]
    end
  end

  def services
    Cmd::Services.new(ARGV).run
  end
end
