# typed: false
# frozen_string_literal: true

require "cmd/services"
require "services"
require "cmd/shared_examples/args_parse"

describe "Homebrew.services_args" do
  it_behaves_like "parseable arguments"
end

describe "brew services" do
  before do
    # Create stub services for testing
    allow(Homebrew::Services::System).to receive(:launchctl?).and_return(true)
    allow(Homebrew::Services::System).to receive(:systemctl?).and_return(false)
    allow(Homebrew::Services::System).to receive(:root?).and_return(false)
  end

  it "has proper implementation structure" do
    expect(Homebrew.method(:services).owner).to eq(Homebrew)
    expect(Homebrew::Cmd::Services).to be_a(Class)
    expect(Homebrew::Cmd::Services).to respond_to(:subcommands)
  end

  describe "integration between legacy and new implementations" do
    before do
      # Stub necessary methods to prevent actual execution
      allow_any_instance_of(Homebrew::Cmd::Services).to receive(:run_new_system)
      allow_any_instance_of(Homebrew::Cmd::Services).to receive(:run_legacy_system)
    end

    it "uses new implementation when --new-system flag is passed" do
      expect_any_instance_of(Homebrew::Cmd::Services).to receive(:run_new_system)
      expect_any_instance_of(Homebrew::Cmd::Services).not_to receive(:run_legacy_system)

      # Create a new instance and call run
      services_cmd = Homebrew::Cmd::Services.new(["--new-system", "list"])
      services_cmd.run
    end

    it "uses new implementation when environment variable is set" do
      old_env = ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"]
      ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"] = "1"

      expect_any_instance_of(Homebrew::Cmd::Services).to receive(:run_new_system)
      expect_any_instance_of(Homebrew::Cmd::Services).not_to receive(:run_legacy_system)

      # Create a new instance and call run
      services_cmd = Homebrew::Cmd::Services.new(["list"])
      services_cmd.run

      # Restore original environment
      if old_env.nil?
        ENV.delete("HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM")
      else
        ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"] = old_env
      end
    end

    it "uses legacy implementation by default" do
      expect_any_instance_of(Homebrew::Cmd::Services).to receive(:run_legacy_system)
      expect_any_instance_of(Homebrew::Cmd::Services).not_to receive(:run_new_system)

      # Create a new instance and call run
      services_cmd = Homebrew::Cmd::Services.new(["list"])
      services_cmd.run
    end
  end

  describe "subcommand implementations" do
    it "defines all required subcommands" do
      # Check that all expected subcommands are registered
      expected_subcommands = %w[
        list info run start stop
        kill restart cleanup
      ]

      registered_subcommands = Homebrew::Cmd::Services.subcommands.keys

      expected_subcommands.each do |subcommand|
        expect(registered_subcommands).to include(subcommand)
      end
    end

    it "has proper List subcommand" do
      list_class = Homebrew::Cmd::Services::List
      expect(list_class.superclass).to eq(Homebrew::AbstractSubcommand)

      parser = list_class.parser
      expect(parser.instance_variable_get(:@parser).to_s).to include("--json")
    end

    it "has proper Run subcommand" do
      run_class = Homebrew::Cmd::Services::Run
      expect(run_class.superclass).to eq(Homebrew::AbstractSubcommand)

      parser = run_class.parser
      expect(parser.instance_variable_get(:@parser).to_s).to include("--file")
      expect(parser.instance_variable_get(:@parser).to_s).to include("--max-wait")
      expect(parser.instance_variable_get(:@parser).to_s).to include("--no-wait")
    end
  end
end
