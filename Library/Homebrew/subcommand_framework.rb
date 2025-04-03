# typed: strict
# frozen_string_literal: true

module Homebrew
  # A framework for adding subcommand support to Homebrew commands.
  # This module provides a consistent way to handle subcommands, including:
  # - Argument parsing
  # - Documentation generation
  # - Shell completion
  # - Subcommand routing
  #
  # To use this framework:
  # 1. Create a module for your command (e.g., Homebrew::SubcommandBundle)
  # 2. Include this module in your command module
  # 3. Define the COMMAND_NAME constant with your primary command name
  # 4. Define the SUBCOMMANDS hash with your subcommands
  # 5. Implement the methods for each subcommand
  #
  # Usage example:
  #
  # ```ruby
  # module Homebrew
  #   module SubcommandBundle
  #     include Homebrew::SubcommandFramework
  #
  #     COMMAND_NAME = "bundle"
  #
  #     SUBCOMMANDS = {
  #       "install" => {
  #         description: "Install all dependencies from the Brewfile",
  #         args: [
  #           [:switch, "--global", description: "Use the global Brewfile"],
  #           # Add more arguments
  #         ],
  #         # Optional custom completion function
  #         completion: ->(shell) { ... },
  #       },
  #       # Add more subcommands
  #     }.freeze
  #
  #     def install(args)
  #       # Implementation of the install subcommand
  #     end
  #   end
  # end
  # ```
  module SubcommandFramework
    class SubcommandArgsError < RuntimeError; end

    class << self
      extend T::Sig

      sig { params(base: Module).void }
      def included(base)
        base.extend(ClassMethods)
      end
    end

    # Class methods for the including module
    module ClassMethods
      extend T::Sig

      # Parse the arguments for a specific subcommand
      sig { params(subcommand: String, args: T::Array[String]).returns(Homebrew::CLI::Args) }
      def parse_subcommand_args(subcommand, args)
        raise "Subcommand '#{subcommand}' not found in #{self::COMMAND_NAME} command" unless self::SUBCOMMANDS.key?(subcommand)

        subcommand_config = self::SUBCOMMANDS[subcommand]
        parser = CLI::Parser.new do
          usage_banner <<~EOS
            `#{self::COMMAND_NAME} #{subcommand}` #{subcommand_config[:usage_banner] || ""}

            #{subcommand_config[:description]}
          EOS

          if subcommand_config[:args]
            subcommand_config[:args].each do |arg_type, *arg_params|
              public_send(arg_type, *arg_params)
            end
          end
        end

        parser.parse(args)
      end

      # Get all available subcommands
      sig { returns(T::Array[String]) }
      def available_subcommands
        self::SUBCOMMANDS.keys
      end

      # Generate shell completion data for the subcommands
      sig { params(shell: Symbol).returns(String) }
      def generate_completions(shell)
        case shell
        when :bash
          generate_bash_completions
        when :zsh
          generate_zsh_completions
        when :fish
          generate_fish_completions
        else
          ""
        end
      end

      # Generate bash completion script for the command's subcommands
      sig { returns(String) }
      def generate_bash_completions
        subcommands_list = available_subcommands.join(" ")

        bash_completion = <<~COMPLETION
          _brew_#{self::COMMAND_NAME}() {
            local cur="\${COMP_WORDS[COMP_CWORD]}"
            case "\${cur}" in
              -*)
                # Add global options here
                __brewcomp "
                --debug
                --help
                --quiet
                --verbose
                #{self::GLOBAL_OPTIONS&.map { |opt| opt.to_s }&.join("\n                ") || ""}
                "
                return
                ;;
              *) ;;
            esac
            __brewcomp "#{subcommands_list}"
          }
        COMPLETION

        bash_completion
      end

      # Generate zsh completion script for the command's subcommands
      sig { returns(String) }
      def generate_zsh_completions
        subcommands_list = available_subcommands.join(" ")

        zsh_completion = <<~COMPLETION
          # brew #{self::COMMAND_NAME}
          _brew_#{self::COMMAND_NAME}() {
            _arguments \\
              '--debug[Display any debugging information]' \\
              '--help[Show this message]' \\
              '--quiet[Make some output more quiet]' \\
              '--verbose[Make some output more verbose]' \\
              #{self::GLOBAL_OPTIONS&.map { |opt, desc| "'#{opt}[#{desc}]' \\\\" }&.join("\n              ") || ""} \\
              - subcommand \\
              '*::subcommand:(#{subcommands_list})'
          }
        COMPLETION

        zsh_completion
      end

      # Generate fish completion script for the command's subcommands
      sig { returns(String) }
      def generate_fish_completions
        subcommands_list = available_subcommands.map { |cmd| "\"#{cmd}\"" }.join(" ")

        fish_completion = <<~COMPLETION
          function __fish_brew_#{self::COMMAND_NAME}_subcommand
            set -l cmd (commandline -opc)
            if [ (count $cmd) -ge 3 ]
              if [ $cmd[2] = "#{self::COMMAND_NAME}" ]
                echo $cmd[3]
                return 0
              end
            end
            return 1
          end

          complete -f -c brew -n "__fish_brew_command #{self::COMMAND_NAME}; and not __fish_brew_#{self::COMMAND_NAME}_subcommand" -a #{subcommands_list}
        COMPLETION

        fish_completion
      end

      # Route the subcommand to the correct method in the module
      sig { params(args: T::Array[String]).void }
      def route_subcommand(args)
        if args.empty? || args.first.start_with?("-")
          # Handle default subcommand or --help, etc.
          default_subcommand = self::DEFAULT_SUBCOMMAND || self::SUBCOMMANDS.keys.first
          handle_subcommand(default_subcommand, args)
        else
          subcommand = args.first
          if self::SUBCOMMANDS.key?(subcommand)
            handle_subcommand(subcommand, args[1..])
          else
            raise Homebrew::CLI::Error, "Unknown #{self::COMMAND_NAME} subcommand: #{subcommand}"
          end
        end
      end

      # Handle the execution of a specific subcommand
      sig { params(subcommand: String, args: T::Array[String]).void }
      def handle_subcommand(subcommand, args)
        parsed_args = parse_subcommand_args(subcommand, args)
        # Find method matching the subcommand in the module
        if respond_to?(subcommand)
          public_send(subcommand, parsed_args)
        else
          raise Homebrew::CLI::Error, "Subcommand method '#{subcommand}' not implemented in #{name}"
        end
      rescue SubcommandArgsError => e
        raise Homebrew::CLI::UsageError, e.message
      end
    end
  end
end
