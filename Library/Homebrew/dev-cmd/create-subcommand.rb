# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "fileutils"
require "cli/parser"

module Homebrew
  module DevCmd
    class CreateSubcommand < AbstractCommand
      cmd_args do
        usage_banner <<~EOS
          `create-subcommand` <command> <subcommand>

          Create a new subcommand for an existing command using the standardized subcommand system.

          This adds the necessary files and boilerplate code to implement a new subcommand.
          For example, `brew create-subcommand bundle cleanup` would create the files needed
          for the `brew bundle cleanup` subcommand.
        EOS

        named_args [:command, :subcommand], min: 2, max: 2
      end

      sig { override.void }
      def run
        command = args.named.first
        subcommand = args.named.second

        # Ensure command exists
        command_path = HOMEBREW_LIBRARY_PATH/"cmd"/command.to_s.tr("-", "_").concat(".rb")
        unless command_path.exist?
          ofail "Command '#{command}' does not exist."
          return
        end

        # Create directory for subcommands if it doesn't exist
        subcommand_dir = HOMEBREW_LIBRARY_PATH/"cmd"/command
        unless subcommand_dir.exist?
          ohai "Creating directory: #{subcommand_dir}"
          FileUtils.mkdir_p subcommand_dir
        end

        # Create the subcommand file
        subcommand_path = subcommand_dir/subcommand.to_s.tr("-", "_").concat(".rb")
        if subcommand_path.exist?
          ofail "Subcommand '#{subcommand}' already exists at #{subcommand_path}."
          return
        end

        # Write template code for the subcommand
        ohai "Creating subcommand file: #{subcommand_path}"
        File.write subcommand_path, subcommand_template(command, subcommand)

        # Check if the command is already using SubcommandableCommand
        unless command_uses_subcommandable?(command_path)
          ohai "Hint: The command #{command} is not yet using SubcommandableCommand."
          puts "You may need to update it to use the new subcommand system."
          puts "See Library/Homebrew/docs/Subcommand-Migration-Guide.md for instructions."
        end

        ohai "Subcommand created successfully!"
        puts "You can now edit the implementation at: #{subcommand_path}"
      end

      private

      sig { params(command_path: Pathname).returns(T::Boolean) }
      def command_uses_subcommandable?(command_path)
        content = File.read(command_path)
        content.include?("SubcommandableCommand") || content.include?("Subcommandable")
      end

      sig { params(command: String, subcommand: String).returns(String) }
      def subcommand_template(command, subcommand)
        module_name = subcommand.split("-").map(&:capitalize).join

        <<~RUBY
          # typed: strict
          # frozen_string_literal: true

          module Homebrew
            # Implementation of the `brew #{command} #{subcommand}` subcommand
            module #{module_name}
              extend T::Sig

              module_function

              sig { params(args: CLI::Args).void }
              def run(args)
                # Your implementation goes here
                ohai "Running #{command} #{subcommand}"
                # Access your options defined in the subcommand block using args
                # For example: if args.verbose? ...
              end
            end
          end
        RUBY
      end
    end
  end
end
