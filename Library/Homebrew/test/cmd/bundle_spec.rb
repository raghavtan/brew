# typed: false
# frozen_string_literal: true

require "cmd/bundle"
require "cmd/shared_examples/args_parse"

describe "Homebrew.bundle_args" do
  it_behaves_like "parseable arguments"
end

describe "brew bundle" do
  it "has proper implementation structure" do
    expect(Homebrew.method(:bundle).owner).to eq(Homebrew)
    expect(Homebrew::Cmd::Bundle).to be_a(Class)
    expect(Homebrew::Cmd::Bundle).to respond_to(:subcommands)
  end

  describe "integration between legacy and new implementations" do
    before do
      # Stub necessary methods to prevent actual execution
      allow_any_instance_of(Homebrew::Cmd::Bundle).to receive(:run_new_system)
      allow_any_instance_of(Homebrew::Cmd::Bundle).to receive(:run_legacy_system)
    end

    it "uses new implementation when --new-system flag is passed" do
      expect_any_instance_of(Homebrew::Cmd::Bundle).to receive(:run_new_system)
      expect_any_instance_of(Homebrew::Cmd::Bundle).not_to receive(:run_legacy_system)

      # Create a new instance and call run
      bundle_cmd = Homebrew::Cmd::Bundle.new(["--new-system", "install"])
      bundle_cmd.run
    end

    it "uses new implementation when environment variable is set" do
      old_env = ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"]
      ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"] = "1"

      expect_any_instance_of(Homebrew::Cmd::Bundle).to receive(:run_new_system)
      expect_any_instance_of(Homebrew::Cmd::Bundle).not_to receive(:run_legacy_system)

      # Create a new instance and call run
      bundle_cmd = Homebrew::Cmd::Bundle.new(["install"])
      bundle_cmd.run

      # Restore original environment
      if old_env.nil?
        ENV.delete("HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM")
      else
        ENV["HOMEBREW_USE_NEW_SUBCOMMAND_SYSTEM"] = old_env
      end
    end

    it "uses legacy implementation by default" do
      expect_any_instance_of(Homebrew::Cmd::Bundle).to receive(:run_legacy_system)
      expect_any_instance_of(Homebrew::Cmd::Bundle).not_to receive(:run_new_system)

      # Create a new instance and call run
      bundle_cmd = Homebrew::Cmd::Bundle.new(["install"])
      bundle_cmd.run
    end
  end

  describe "subcommand implementations" do
    it "defines all required subcommands" do
      # Check that all expected subcommands are registered
      expected_subcommands = %w[
        install dump cleanup check
        list edit exec sh env add remove
      ]

      registered_subcommands = Homebrew::Cmd::Bundle.subcommands.keys

      expected_subcommands.each do |subcommand|
        expect(registered_subcommands).to include(subcommand)
      end
    end

    it "has proper Install subcommand" do
      install_class = Homebrew::Cmd::Bundle::Install
      expect(install_class.superclass).to eq(Homebrew::AbstractSubcommand)

      parser = install_class.parser
      expect(parser.instance_variable_get(:@parser).to_s).to include("--no-upgrade")
      expect(parser.instance_variable_get(:@parser).to_s).to include("--upgrade")
      expect(parser.instance_variable_get(:@parser).to_s).to include("--upgrade-formulae")
      expect(parser.instance_variable_get(:@parser).to_s).to include("--force")
      expect(parser.instance_variable_get(:@parser).to_s).to include("--cleanup")
    end
  end

  it "checks if a Brewfile's dependencies are satisfied", :integration_test do
    HOMEBREW_REPOSITORY.cd do
      system "git", "init"
      system "git", "commit", "--allow-empty", "-m", "This is a test commit"
    end

    mktmpdir do |path|
      FileUtils.touch "#{path}/Brewfile"
      path.cd do
        expect { brew "bundle", "check" }
          .to output("The Brewfile's dependencies are satisfied.\n").to_stdout
          .and not_to_output.to_stderr
          .and be_a_success
      end
    end
  end
end
