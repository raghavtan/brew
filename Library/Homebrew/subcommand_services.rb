# typed: strict
# frozen_string_literal: true

require "subcommand_framework"

module Homebrew
  # Example implementation of the SubcommandServices module for handling `brew services` commands
  # This demonstrates how to use the SubcommandFramework to implement a command with subcommands
  module SubcommandServices
    include Homebrew::SubcommandFramework

    COMMAND_NAME = "services"
    DEFAULT_SUBCOMMAND = "list"

    # Global options applicable to all subcommands
    GLOBAL_OPTIONS = {
      "--file=" => "Use the service file from this location to `start` the service.",
      "--sudo-service-user=" => "When run as root on macOS, run the service(s) as this user.",
    }.freeze

    # Definition of each subcommand, its description, and arguments
    SUBCOMMANDS = {
      "list" => {
        description: "List information about all managed services for the current user (or root).",
        args: [
          [:switch, "--json", {
            description: "Output as JSON."
          }],
        ],
      },
      "info" => {
        description: "List all managed services for the current user (or root).",
        args: [
          [:switch, "--all", {
            description: "Show information about all services."
          }],
          [:switch, "--json", {
            description: "Output as JSON."
          }],
        ],
      },
      "run" => {
        description: "Run the service without registering to launch at login (or boot).",
        args: [
          [:switch, "--all", {
            description: "Run all available services."
          }],
          [:flag, "--file=", {
            description: "Use the service file from this location to run the service."
          }],
        ],
      },
      "start" => {
        description: "Start the service immediately and register it to launch at login (or boot).",
        args: [
          [:switch, "--all", {
            description: "Start all available services."
          }],
          [:flag, "--file=", {
            description: "Use the service file from this location to start the service."
          }],
        ],
      },
      "stop" => {
        description: "Stop the service immediately and unregister it from launching at login (or boot).",
        args: [
          [:switch, "--all", {
            description: "Stop all running services."
          }],
          [:switch, "--keep", {
            description: "When stopped, don't unregister the service from launching at login (or boot)."
          }],
          [:switch, "--no-wait", {
            description: "Don't wait for `stop` to finish stopping the service."
          }],
          [:flag, "--max-wait=", {
            description: "Wait at most this many seconds for `stop` to finish stopping a service. " \
                         "Omit this flag or set this to zero (0) seconds to wait indefinitely."
          }],
        ],
      },
      "kill" => {
        description: "Stop the service immediately but keep it registered to launch at login (or boot).",
        args: [
          [:switch, "--all", {
            description: "Kill all running services."
          }],
        ],
      },
      "restart" => {
        description: "Stop (if necessary) and start the service immediately and register it to launch at login (or boot).",
        args: [
          [:switch, "--all", {
            description: "Restart all running services."
          }],
          [:flag, "--file=", {
            description: "Use the service file from this location to restart the service."
          }],
        ],
      },
      "cleanup" => {
        description: "Remove all unused services.",
        args: [],
      },
    }.freeze

    class << self
      extend T::Sig

      # Example implementation of the list subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def list(args)
        puts "Would run services list with args: #{args.inspect}"
      end

      # Example implementation of the info subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def info(args)
        puts "Would run services info with args: #{args.inspect}"
      end

      # Example implementation of the run subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def run(args)
        puts "Would run services run with args: #{args.inspect}"
      end

      # Example implementation of the start subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def start(args)
        puts "Would run services start with args: #{args.inspect}"
      end

      # Example implementation of the stop subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def stop(args)
        puts "Would run services stop with args: #{args.inspect}"
      end

      # Example implementation of the kill subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def kill(args)
        puts "Would run services kill with args: #{args.inspect}"
      end

      # Example implementation of the restart subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def restart(args)
        puts "Would run services restart with args: #{args.inspect}"
      end

      # Example implementation of the cleanup subcommand
      sig { params(args: Homebrew::CLI::Args).void }
      def cleanup(args)
        puts "Would run services cleanup with args: #{args.inspect}"
      end
    end
  end
end
