# typed: false
# frozen_string_literal: true

require "abstract_subcommand"
require "subcommand_parser"

describe Homebrew::AbstractSubcommandableMixin do
  let(:test_command_class) do
    Class.new(Homebrew::AbstractCommand) do
      include Homebrew::AbstractSubcommandableMixin
      include Homebrew::SubcommandDispatchMixin

      shared_args do
        usage_banner <<~EOS
          `test` [<subcommand>]

          Test command with subcommands
        EOS

        switch "--shared-flag", description: "A flag that is shared across all subcommands"
      end

      cmd_args do
        switch "--main-flag", description: "A flag only for the main command"
      end

      def run
        puts "Main command executed"
      end
    end
  end

  let(:test_subcommand_class) do
    Class.new(Homebrew::AbstractSubcommand) do
      cmd_args do
        usage_banner <<~EOS
          `test action`

          Test subcommand
        EOS

        switch "--subcommand-flag", description: "A flag only for this subcommand"
      end

      def run
        puts "Subcommand executed"
      end
    end
  end

  before do
    # Setup the class hierarchy for testing
    stub_const("Homebrew::TestCmd::Test", test_command_class)
    stub_const("Homebrew::TestCmd::Test::Action", test_subcommand_class)

    # Register the subcommand
    Homebrew::TestCmd::Test.register_subcommand(Homebrew::TestCmd::Test::Action, ["action", "a", "act"])
  end

  describe "subcommand registration" do
    it "registers subcommands with their aliases" do
      expect(Homebrew::TestCmd::Test.subcommands).to include("action")
      expect(Homebrew::TestCmd::Test.subcommands).to include("a")
      expect(Homebrew::TestCmd::Test.subcommands).to include("act")
      expect(Homebrew::TestCmd::Test.subcommands.count).to eq(3)
    end

    it "allows access to the subcommand class via its name" do
      expect(Homebrew::TestCmd::Test.subcommands["action"]).to eq(Homebrew::TestCmd::Test::Action)
    end
  end

  describe "argument inheritance" do
    it "includes shared arguments in the subcommand parser" do
      parser = Homebrew::TestCmd::Test::Action.parser
      expect(parser.instance_variable_get(:@parser).to_s).to include("--shared-flag")
    end

    it "includes subcommand-specific arguments" do
      parser = Homebrew::TestCmd::Test::Action.parser
      expect(parser.instance_variable_get(:@parser).to_s).to include("--subcommand-flag")
    end

    it "does not include parent-only arguments" do
      parser = Homebrew::TestCmd::Test::Action.parser
      expect(parser.instance_variable_get(:@parser).to_s).not_to include("--main-flag")
    end
  end

  describe Homebrew::SubcommandParser do
    it "extracts the subcommand name and remaining arguments" do
      args = ["action", "--shared-flag", "--subcommand-flag"]
      parent_command = instance_double(Homebrew::TestCmd::Test)
      allow(parent_command).to receive(:available_subcommands_help).and_return("")
      allow(parent_command).to receive(:class).and_return(Homebrew::TestCmd::Test)

      subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args, parent_command)

      expect(subcommand_name).to eq("action")
      expect(remaining_args).to eq(["--shared-flag", "--subcommand-flag"])
    end

    it "handles the case with no subcommand" do
      args = ["--shared-flag"]
      parent_command = instance_double(Homebrew::TestCmd::Test)
      allow(parent_command).to receive(:available_subcommands_help).and_return("")
      allow(parent_command).to receive(:class).and_return(Homebrew::TestCmd::Test)

      subcommand_name, remaining_args = Homebrew::SubcommandParser.parse_subcommand(args, parent_command)

      expect(subcommand_name).to be_nil
      expect(remaining_args).to eq(["--shared-flag"])
    end
  end
end