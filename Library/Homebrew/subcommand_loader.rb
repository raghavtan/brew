# typed: strict
# frozen_string_literal: true

module Homebrew
  # A class that handles loading subcommand implementations.
  # This supports loading subcommands from individual files in a subdirectory
  # structure like cmd/bundle/*.rb.
  class SubcommandLoader
    extend T::Sig

    sig { params(command_name: String).void }
    def initialize(command_name)
      @command_name = command_name
    end

    sig { params(subcommand_name: String).returns(T.nilable(Module)) }
    def load_subcommand(subcommand_name)
      # First, try to find the subcommand in the standard location
      subcommand_path = subcommand_file_path(subcommand_name)

      return nil unless File.exist?(subcommand_path)

      require subcommand_path

      # After requiring the file, look for a module with the expected name
      subcommand_module_name = subcommand_module_name_for(subcommand_name)

      # Try to find the module in the Homebrew namespace
      Homebrew.const_get(subcommand_module_name) if Homebrew.const_defined?(subcommand_module_name)
    rescue LoadError, NameError
      nil
    end

    private

    sig { params(subcommand_name: String).returns(String) }
    def subcommand_file_path(subcommand_name)
      normalized_name = subcommand_name.tr("-", "_")
      File.join(HOMEBREW_LIBRARY_PATH, "cmd", @command_name, "#{normalized_name}.rb")
    end

    sig { params(subcommand_name: String).returns(String) }
    def subcommand_module_name_for(subcommand_name)
      # Convert from kebab-case to CamelCase
      # e.g., "foo-bar" becomes "FooBar"
      subcommand_name.split("-").map(&:capitalize).join
    end
  end
end
