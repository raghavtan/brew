# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "subcommand_framework"
require "subcommand_services"
require "services/system"
require "services/commands/list"
require "services/commands/cleanup"
require "services/commands/info"
require "services/commands/restart"
require "services/commands/run"
require "services/commands/start"
require "services/commands/stop"
require "services/commands/kill"

module Homebrew
  module Cmd
    class Services < AbstractCommand
      cmd_args do
        usage_banner <<~EOS
          `services` [<subcommand>]

          Manage background services with macOS' `launchctl`(1) daemon manager or
          Linux's `systemctl`(1) service manager.

          If `sudo` is passed, operate on `/Library/LaunchDaemons` or `/usr/lib/systemd/system`  (started at boot).
          Otherwise, operate on `~/Library/LaunchAgents` or `~/.config/systemd/user` (started at login).

          [`sudo`] `brew services` [`list`] (`--json`) (`--debug`):
          List information about all managed services for the current user (or root).
          Provides more output from Homebrew and `launchctl`(1) or `systemctl`(1) if run with `--debug`.

          [`sudo`] `brew services info` (<formula>|`--all`|`--json`):
          List all managed services for the current user (or root).

          [`sudo`] `brew services run` (<formula>|`--all`|`--file=`):
          Run the service <formula> without registering to launch at login (or boot).

          [`sudo`] `brew services start` (<formula>|`--all`|`--file=`):
          Start the service <formula> immediately and register it to launch at login (or boot).

          [`sudo`] `brew services stop` (`--keep`) (`--no-wait`|`--max-wait=`) (<formula>|`--all`):
          Stop the service <formula> immediately and unregister it from launching at login (or boot),
          unless `--keep` is specified.

          [`sudo`] `brew services kill` (<formula>|`--all`):
          Stop the service <formula> immediately but keep it registered to launch at login (or boot).

          [`sudo`] `brew services restart` (<formula>|`--all`|`--file=`):
          Stop (if necessary) and start the service <formula> immediately and register it to launch at login (or boot).

          [`sudo`] `brew services cleanup`:
          Remove all unused services.
        EOS
        flag "--file=", description: "Use the service file from this location to `start` the service."
        flag "--sudo-service-user=", description: "When run as root on macOS, run the service(s) as this user."
        flag "--max-wait=", description: "Wait at most this many seconds for `stop` to finish stopping a service. " \
                                         "Omit this flag or set this to zero (0) seconds to wait indefinitely."
        switch "--all", description: "Run <subcommand> on all services."
        switch "--json", description: "Output as JSON."
        switch "--no-wait", description: "Don't wait for `stop` to finish stopping the service."
        switch "--keep", description: "When stopped, don't unregister the service from launching at login (or boot)."
        conflicts "--max-wait=", "--no-wait"
        named_args %w[list info run start stop kill restart cleanup]
      end

      sig { override.void }
      def run
        # pbpaste's exit status is a proxy for detecting the use of reattach-to-user-namespace
        if ENV.fetch("HOMEBREW_TMUX", nil) && File.exist?("/usr/bin/pbpaste") && !quiet_system("/usr/bin/pbpaste")
          raise UsageError,
                "`brew services` cannot run under tmux!"
        end

        # Keep this after the .parse to keep --help fast.
        require "utils"

        if !Homebrew::Services::System.launchctl? && !Homebrew::Services::System.systemctl?
          raise UsageError,
                "`brew services` is supported only on macOS or Linux (with systemd)!"
        end

        if (sudo_service_user = args.sudo_service_user)
          unless Homebrew::Services::System.root?
            raise UsageError,
                  "`brew services` is supported only when running as root!"
          end

          unless Homebrew::Services::System.launchctl?
            raise UsageError,
                  "`brew services --sudo-service-user` is currently supported only on macOS " \
                  "(but we'd love a PR to add Linux support)!"
          end

          Homebrew::Services::Cli.sudo_service_user = sudo_service_user
        end

        # Route the command to our new SubcommandServices module that implements
        # the SubcommandFramework

        # Map the parsed args to an array of strings to pass to the SubcommandServices
        # This is a temporary solution until we fully migrate to the new framework
        argv = []

        # Add named args (subcommand and its arguments)
        argv.concat(args.named)

        # Add option flags
        argv << "--file=#{args.file}" if args.file
        argv << "--sudo-service-user=#{args.sudo_service_user}" if args.sudo_service_user
        argv << "--max-wait=#{args.max_wait}" if args.max_wait
        argv << "--all" if args.all?
        argv << "--json" if args.json?
        argv << "--no-wait" if args.no_wait?
        argv << "--keep" if args.keep?

        SubcommandServices.route_subcommand(argv)
      end
    end
  end
end
