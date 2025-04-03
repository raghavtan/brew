# typed: strict
# frozen_string_literal: true

require "completions"
require "commands"
require "extend/ENV"

module Homebrew
  class CompletionsGenerator
    include Context

    extend T::Sig

    attr_reader :shells, :formula, :cask

    sig {
      params(
        shells:  T::Array[Symbol],
        formula: T::Boolean,
        cask:    T::Boolean,
      ).void
    }
    def initialize(shells:, formula: false, cask: false)
      @shells = shells
      @formula = formula
      @cask = cask
    end

    sig { void }
    def run
      homes = {}
      unless formula || cask
        std_paths = ENV["HOMEBREW_PATH"]&.split(":")
                                          &.grep(%r{^#{Regexp.escape(HOMEBREW_PREFIX)}/[^/]+/?$})
                                          &.map { |path| path.chomp("/") } || []
        homes = Dir["#{HOMEBREW_REPOSITORY}/Library/Taps/*/*/"].each_with_object({}) do |tap_path, hash|
          next if tap_path.end_with?("/Homebrew/brew/")

          hash[tap_path] = "brew-tap-#{tap_path.split("/")[-2]}-#{tap_path.split("/")[-1]}"
        end
        # Ensure that the preferred shell PATH is used.
        ENV["PATH"] = ENV.fetch("HOMEBREW_PATH", nil)
      end

      shells.each do |shell|
        generate_completions(shell, homes)
      end
    end

    private

    sig { params(shell: Symbol, homes: T::Hash[String, String]).void }
    def generate_completions(shell, homes)
      load_completions(shell)

      if formula
        generate_formula_completions(shell)
      elsif cask
        generate_cask_completions(shell)
      else
        generate_internal_commands_completions(shell)
        generate_external_commands_completions(shell, homes)
        generate_subcommand_framework_completions(shell) # New method to generate completions for subcommand framework modules
      end
    end

    sig { params(shell: Symbol).void }
    def load_completions(shell)
      return unless COMPLETIONS_DIR.exist?

      Dir["#{COMPLETIONS_DIR}/#{shell}/*"].each do |path|
        next if path.end_with?("brew")

        Homebrew.require path
      end
    end

    sig { params(shell: Symbol).void }
    def generate_formula_completions(shell)
      case shell
      when :bash
        puts "# Bash completion function", "have brew || alias brew=#{HOMEBREW_PREFIX}/bin/brew"
        puts IO.read("#{COMPLETIONS_DIR}/bash/brew")
        puts "__brewcomp_words_include() {"
        puts "  local i=1 word j loop_"
        puts "  for word in $1; do"
        puts "    if [[ $word = \"$2\" ]]; then"
        puts "      return 0"
        puts "    fi"
        puts "    for ((j=0; j < ${#COMP_WORDS[@]}; j++)); do"
        puts "      if [[ ${COMP_WORDS[j]} = \"$word\" ]]; then"
        puts "        loop_=1"
        puts "        if [[ $i -eq $COMP_CWORD ]]; then"
        puts "          return 0"
        puts "        else"
        puts "          ((i++))"
        puts "        fi"
        puts "      fi"
        puts "      if [[ $j -eq ${#COMP_WORDS[@]}-1 && $loop_ ]]; then"
        puts "        break"
        puts "      fi"
        puts "    done"
        puts "    loop_="
        puts "  done"
        puts "  return 1"
        puts "}"
        puts "_brew_formulae_all() {"
        puts "  local _comp_formulae=$(brew formulae)"
        puts "  local _comp_formulae_all=$_comp_formulae"
        puts "  COMPREPLY+=($(compgen -W \"$_comp_formulae_all\" -- \"${cur}\"))"
        puts "  __brewcomp_words_include \"$_comp_formulae\" \"${cur}\" && return 0"
        puts "}"
        puts "_brew_complete_formulae() { _brew_formulae_all; }"
      when :fish
        puts "function __fish_brew_formulae_all"
        puts "  # get all formulae
        set -l complete_formulae (brew formulae)"
        puts "  for formula in (echo $complete_formulae)"
        puts "    echo $formula"
        puts "  end"
        puts "end"
        puts "complete -c brew -x -a \"(__fish_brew_formulae_all)\" -d \"Formula\""
      end
    end

    sig { params(shell: Symbol).void }
    def generate_cask_completions(shell)
      case shell
      when :bash
        puts "# Bash completion function", "have brew || alias brew=#{HOMEBREW_PREFIX}/bin/brew"
        puts IO.read("#{COMPLETIONS_DIR}/bash/brew")
        puts "__brewcomp_words_include() {"
        puts "  local i=1 word j loop_"
        puts "  for word in $1; do"
        puts "    if [[ $word = \"$2\" ]]; then"
        puts "      return 0"
        puts "    fi"
        puts "    for ((j=0; j < ${#COMP_WORDS[@]}; j++)); do"
        puts "      if [[ ${COMP_WORDS[j]} = \"$word\" ]]; then"
        puts "        loop_=1"
        puts "        if [[ $i -eq $COMP_CWORD ]]; then"
        puts "          return 0"
        puts "        else"
        puts "          ((i++))"
        puts "        fi"
        puts "      fi"
        puts "      if [[ $j -eq ${#COMP_WORDS[@]}-1 && $loop_ ]]; then"
        puts "        break"
        puts "      fi"
        puts "    done"
        puts "    loop_="
        puts "  done"
        puts "  return 1"
        puts "}"
        puts "_brew_casks_all() {"
        puts "  local _comp_casks=$(brew casks)"
        puts "  local _comp_casks_all=$_comp_casks"
        puts "  COMPREPLY+=($(compgen -W \"$_comp_casks_all\" -- \"${cur}\"))"
        puts "  __brewcomp_words_include \"$_comp_casks\" \"${cur}\" && return 0"
        puts "}"
        puts "_brew_complete_casks() { _brew_casks_all; }"
      when :fish
        puts "function __fish_brew_casks_all"
        puts "  # get all casks
        set -l complete_casks (brew casks)"
        puts "  for cask in (echo $complete_casks)"
        puts "    echo $cask"
        puts "  end"
        puts "end"
        puts "complete -c brew -x -a \"(__fish_brew_casks_all)\" -d \"Cask\""
      end
    end

    sig { params(shell: Symbol).void }
    def generate_internal_commands_completions(shell)
      cmds = internal_commands_paths(Commands::HOMEBREW_CMD_PATH, Commands::PATH_ALLOWED_EXTENSIONS).
             map { |path| Commands.path_to_cmd(path) }

      internal_commands = (cmds + internal_developer_commands).sort

      case shell
      when :bash
        puts "# Bash completion function", "have brew || alias brew=#{HOMEBREW_PREFIX}/bin/brew"
        puts IO.read("#{COMPLETIONS_DIR}/bash/brew")
      when :fish
        puts "for cmd in #{fish_expand_cmd(internal_commands)}"
        puts "  complete -c brew -f -n '__fish_brew_command_has_option_or_subcommand $cmd' -a '(__fish_brew_options_or_subcommands \"$cmd\")'"
        puts "end"
      when :zsh
        puts IO.read("#{COMPLETIONS_DIR}/zsh/_brew")
      end
    end

    sig { params(shell: Symbol, homes: T::Hash[String, String]).void }
    def generate_external_commands_completions(shell, homes)
      cmds, ext_names = external_commands

      cmds.each do |cmd, ext_name|
        cmd_path = which("#{cmd}.#{ext_name}")
        next unless cmd_path

        homes.each do |brew_home, name|
          break if cmd_path.start_with?(brew_home) &&
                  cmd_path.sub(brew_home, "").include?("/")

          cmd = "#{name} #{cmd}" if name
        end

        generate_external_command_completion(shell, cmd, cmd_path)
      end
    end

    sig { params(shell: Symbol).void }
    def generate_subcommand_framework_completions(shell)
      # Find all modules that include the SubcommandFramework
      require "subcommand_framework"

      subcommand_modules = ObjectSpace.each_object(Module).select do |mod|
        mod.included_modules.include?(Homebrew::SubcommandFramework) rescue false
      end

      # For each module, generate the completions for the specified shell
      subcommand_modules.each do |mod|
        next unless mod.respond_to?(:generate_completions) && mod.respond_to?(:COMMAND_NAME)

        # Output the completions for the current shell
        puts mod.generate_completions(shell)
      end
    end

    sig { params(path: String, extensions: T::Array[String]).returns(T::Array[Pathname]) }
    def internal_commands_paths(path, extensions)
      Pathname.glob("#{path}/*")
              .select { |pn| pn.file? && extensions.include?(pn.extname) }
              .sort
    end

    sig { returns(T::Array[String]) }
    def internal_developer_commands
      Pathname.glob("#{Commands::HOMEBREW_DEV_CMD_PATH}/{,**/}*")
              .select(&:file?)
              .map { |pn| pn.basename(Commands::PATH_ALLOWED_EXTENSIONS.first).to_s }
              .sort
    end

    sig { returns([T::Array[String], T::Array[String]]) }
    def external_commands
      cmds = []
      ext_names = []

      Homebrew::Completions::EXTERNAL_CMD_PATHS.each do |ext_path|
        # The extension itself checks if it grants the capability, ensuring that
        # just adding a path to the constant definition doesn't suddenly activate
        # an extension that should otherwise be inactive.
        extensions = Pathname.glob("#{ext_path}/*").select do |pn|
          if Commands::PATH_ALLOWLIST_EXTENSIONS.include?(pn.extname)
            true
          elsif Commands::PATH_BLOCKLIST_EXTENSIONS.include?(pn.extname)
            false
          # Do not try to execute, e.g., .app files
          elsif Commands::PATH_DISCOURAGED_EXTENSIONS.include?(pn.extname)
            false
          elsif Homebrew::EnvConfig.developer? && Commands::PATH_ALLOWED_EXTENSIONS.include?(pn.extname)
            true
          elsif pn.executable?
            true
          end
        end

        exts = extensions.map(&:extname)
        ext_names.concat(exts)

        extensions.map { |pn| [pn.basename(pn.extname).to_s, pn.extname] }.each do |cmd, ext|
          next if cmd.start_with?(".")
          next if Commands::INTERNAL_COMMAND_ALIASES.include?(cmd)
          next if ext == ".tar.gz" # How are we supposed to handle this?

          cmds << [cmd, ext.delete(".")]
        end
      end

      [cmds, ext_names.uniq]
    end

    sig { params(array: T::Array[String]).returns(String) }
    def fish_expand_cmd(array)
      return "" if array.empty?

      array.map do |item|
        next item unless item.include? " "

        "\"#{item}\""
      end.join(" ")
    end

    sig { params(shell: Symbol, cmd: String, cmd_path: Pathname).void }
    def generate_external_command_completion(shell, cmd, cmd_path)
      return if cmd =~ /^\./

      cmd_desc = get_cmd_description(cmd_path)

      case shell
      when :bash
        puts <<~COMPLETION
          # brew #{cmd} completion
          _brew_#{cmd.tr("-", "_").tr(" ", "-")}() {
            ::add_brew_parity
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
              __brewcomp "
          }
          Complete -F _brew_#{cmd.tr("-", "_").tr(" ", "-")} #{cmd}
        COMPLETION
      when :fish
        puts "# brew #{cmd} completion"
        puts <<~COMPLETION
          complete -c brew -f -n '__fish_brew_command_has_option_or_subcommand #{cmd}' -a '(__fish_brew_options_or_subcommands \"#{cmd}\")'
        COMPLETION
      when :zsh
        puts "# brew #{cmd} completion"
        puts <<~COMPLETION
          # _brew_#{cmd.tr("-", "_").tr(" ", "-")}() {
          #   local ret=1
          # }
          # _brew_#{cmd.tr("-", "_").tr(" ", "-")}
        COMPLETION
      end
    end

    sig { params(cmd_path: Pathname).returns(String) }
    def get_cmd_description(cmd_path)
      description_regex = /^#:  \* `([^`]*)`(?: *): *(.*)$/

      cmd_path.each_line do |line|
        match = line.match(description_regex)
        return match.captures.second if match
      rescue ArgumentError
        return "Unknown command description"
      end

      "Unknown command description"
    end
  end
end
