# typed: strict
# frozen_string_literal: true

module Homebrew
  # Helper module for generating documentation for commands with subcommands.
  module SubcommandDocs
    extend T::Sig

    module_function

    sig { params(command: T.class_of(AbstractCommand)).returns(String) }
    def generate_usage_banner(command)
      # Generate a usage banner for a command with subcommands
      subcommands = command.subcommands.keys.uniq.sort
      default_subcmd = command.default_subcommand

      banner = "Usage: brew #{command.command_name} [<subcommand>]"
      banner += "\n\nSubcommands:"

      # Group subcommands by their source module to avoid duplicating aliases
      subcommand_map = command.subcommands.values.uniq.group_by(&:name)

      subcommand_map.each do |_name, cmds|
        subcmd = cmds.first

        # Skip displaying aliases as separate items, but include them in the descriptions
        next if subcmd.name != subcmd.name

        # Format the subcommand name and any aliases
        cmd_line = "  #{subcmd.name}"
        if subcmd.aliases.any?
          cmd_line += " (#{subcmd.aliases.join(", ")})"
        end
        cmd_line += " #{default_subcmd == subcmd.name ? "(default)" : ""}"

        # Add the description if available
        cmd_line = cmd_line.ljust(24) + (subcmd.description || "")
        banner += "\n#{cmd_line}"
      end

      banner
    end

    sig { params(command: T.class_of(AbstractCommand)).returns(String) }
    def generate_man_page(command)
      # Generate a manpage for a command with subcommands
      man_page = ""
      man_page += "brew-#{command.command_name}(1) -- #{command.parser.description}\n"
      man_page += "=" * 80 + "\n\n"

      man_page += "## SYNOPSIS\n\n"
      man_page += "`brew #{command.command_name}` [<subcommand>] [<options>]\n\n"

      man_page += "## DESCRIPTION\n\n"
      man_page += "#{command.parser.description}\n\n" if command.parser.description

      man_page += "## SUBCOMMANDS\n\n"

      # Group subcommands by their actual implementation
      command.subcommands.values.uniq.each do |subcmd|
        man_page += "### `#{subcmd.name}`"

        # Show aliases if any
        if subcmd.aliases.any?
          man_page += " (aliases: #{subcmd.aliases.join(", ")})"
        end

        # Mark if this is the default subcommand
        if command.default_subcommand == subcmd.name
          man_page += " (default)"
        end

        man_page += "\n\n"

        # Add the description
        man_page += "#{subcmd.description}\n\n" if subcmd.description

        # Add subcommand-specific options if any
        if subcmd.parser.options.any?
          man_page += "Options:\n\n"

          subcmd.parser.options.each do |opt|
            man_page += "* `#{opt.flag}`: #{opt.description}\n"
          end

          man_page += "\n"
        end
      end

      # Add global options
      man_page += "## GLOBAL OPTIONS\n\n"

      command.parser.options.each do |opt|
        man_page += "* `#{opt.flag}`: #{opt.description}\n"
      end

      man_page
    end

    sig { params(command: T.class_of(AbstractCommand)).returns(String) }
    def generate_shell_completion(command)
      # Generate shell completion script for a command with subcommands
      completion = ""

      # Get all unique subcommands
      subcommands = command.subcommands.keys.uniq.sort

      # Basic completion function for Bash
      completion += <<~SH
        _brew_#{command.command_name}_complete() {
          local cur="${COMP_WORDS[COMP_CWORD]}"
          local subcommand="${COMP_WORDS[1]}"

          if [[ ${COMP_CWORD} -eq 1 ]] ; then
            COMPREPLY=( $(compgen -W "#{subcommands.join(" ")}" -- "$cur") )
            return
          fi

          # Subcommand-specific completions
          case "$subcommand" in
      SH

      # Add specific completions for each subcommand
      command.subcommands.values.uniq.each do |subcmd|
        completion += <<~SH
            #{subcmd.name})
              COMPREPLY=( $(compgen -W "#{subcmd.parser.options.map(&:flag).join(" ")}" -- "$cur") )
              ;;
        SH
      end

      # Close out the case statement and function
      completion += <<~SH
          esac
        }

        complete -F _brew_#{command.command_name}_complete brew #{command.command_name}
      SH

      completion
    end
  end
end
