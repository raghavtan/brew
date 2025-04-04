# typed: strict
# frozen_string_literal: true

module Homebrew
  # A parameter object for command options to reduce parameter lists
  class CommandOptions
    extend T::Sig

    sig { returns(T::Boolean) }
    attr_reader :global, :verbose, :no_wait, :keep, :zap, :force

    sig { returns(T.nilable(String)) }
    attr_reader :file

    sig { returns(T.nilable(Float)) }
    attr_reader :max_wait

    sig { params(args: T.untyped).void }
    def initialize(args)
      @global = args.respond_to?(:global?) ? args.global? : false
      @file = args.respond_to?(:file) ? args.file : nil
      @verbose = args.respond_to?(:verbose?) ? args.verbose? : false
      @no_wait = args.respond_to?(:no_wait?) ? args.no_wait? : false
      @max_wait = args.respond_to?(:max_wait) ? args.max_wait.to_f : nil
      @keep = args.respond_to?(:keep?) ? args.keep? : false
      @zap = args.respond_to?(:zap?) ? args.zap? : false
      @force = args.respond_to?(:force?) ? args.force? : false
    end

    sig { returns(T::Hash[Symbol, T.untyped]) }
    def to_h
      {
        global: @global,
        file: @file,
        verbose: @verbose,
        no_wait: @no_wait,
        max_wait: @max_wait,
        keep: @keep,
        zap: @zap,
        force: @force
      }
    end
  end
end
