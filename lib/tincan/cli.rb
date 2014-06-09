$stdout.sync = true

require 'yaml'
require 'erb'
require 'singleton'
require 'optparse'
require 'fileutils'
require 'logger'
require 'active_support/core_ext/hash/indifferent_access'

require 'tincan/receiver'
require 'tincan/version'

module Tincan
  class Shutdown < Interrupt; end

  class CLI
    include Singleton

    # Used for CLI testing
    attr_accessor :code
    attr_accessor :receiver
    attr_accessor :environment
    attr_accessor :logger
    attr_accessor :config
    attr_accessor :thread

    def initialize
      @code = nil
    end

    def parse(args = ARGV)
      @code = nil

      setup_config(args)
      initialize_logger
      check_required_keys!
      validate!
      daemonize
      write_pid
    end

    def run
      boot_system
      print_banner

      self_read, self_write = IO.pipe

      %w(INT TERM USR1 USR2 TTIN).each do |sig|
        begin
          trap sig do
            self_write.puts(sig)
          end
        rescue ArgumentError
          puts "Signal #{sig} not supported."
        end
      end

      logger.info "Running in #{RUBY_DESCRIPTION}."

      unless config[:daemon]
        logger.info 'Now listening for notifications. Hit Ctrl-C to stop.'
      end

      ## TODO: FIX THIS

      @receiver = Tincan::Receiver.new do |r|
        r.logger = @logger
        r.redis_host = config[:redis_host]
        r.client_name = config[:client_name]
        r.namespace = config[:namespace]
        r.listen_to = Hash[config[:listen_to].map do |object, runners|
          [object.to_sym, runners.map do |runner|
            klass, method_name = runner.split('.')
            klass = klass.constantize
            ->(data) { klass.send(method_name.to_sym, data) }
          end]
        end]
        r.on_exception = lambda do |ex, context|
          @logger.error ex
          @logger.error ex.backtrace
          Airbrake.notify_or_ignore(ex, parameters: context)
        end
      end

      begin
        @thread = Thread.new { @receiver.listen }

        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          handle_signal(signal)
        end
      rescue Interrupt
        logger.info 'Shutting down.'
        # @thread.stop
        exit(0)
      end
    end

    private

    def print_banner
      # Print logo and banner for development
      return unless environment == 'development' && $stdout.tty?
      puts "\e[#{31}m"
      puts 'Welcome to tincan!'
      puts "\e[0m"
    end

    def handle_signal(sig)
      @logger.debug "Got #{sig} signal"
      case sig
      when 'INT'
        fail Interrupt
      when 'TERM'
        fail Interrupt
      when 'USR1'
        @logger.info 'Received USR1, no longer accepting new work'
        @thread.stop
      # when 'USR2'
      #   if config[:logfile]
      #     @logger.info 'Received USR2, reopening log file'
      #     Tincan::Logging.reopen_logs
      #   end
      when 'TTIN'
        Thread.list.each do |thread|
          label = thread['label']
          @logger.info "Thread TID-#{thread.object_id.to_s(36)} #{label}"
          if thread.backtrace
            @logger.info thread.backtrace.join("\n")
          else
            @logger.info '<no backtrace available>'
          end
        end
      end
    end

    def daemonize
      return unless config[:daemon]

      unless config[:logfile]
        fail ArgumentError,
             "You really should set a logfile if you're going to daemonize"
      end
      files_to_reopen = []
      ObjectSpace.each_object(File) do |file|
        files_to_reopen << file unless file.closed?
      end

      ::Process.daemon(true, true)

      files_to_reopen.each do |file|
        begin
          file.reopen file.path, 'a+'
          file.sync = true
        rescue ::Exception
        end
      end

      [$stdout, $stderr].each do |io|
        File.open(config[:logfile], 'ab') do |f|
          io.reopen(f)
        end
        io.sync = true
      end
      $stdin.reopen('/dev/null')

      initialize_logger
    end

    def set_environment(cli_env)
      @environment = cli_env || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def setup_config(args)
      opts = parse_options(args)
      set_environment opts[:environment]
      opts = parse_config(opts[:config_file]).merge(opts) if opts[:config_file]
      opts[:strict] = true if opts[:strict].nil?
      @config = opts
    end

    def boot_system
      ENV['RACK_ENV'] = ENV['RAILS_ENV'] = environment

      unless File.exist?(config[:require])
        fail ArgumentError, "#{config[:require]} does not exist"
      end

      if File.directory?(config[:require])
        require 'rails'
        require File.expand_path("#{config[:require]}/config/environment.rb")
        ::Rails.application.eager_load!
        config[:tag] = default_tag
      else
        require config[:require]
      end
    end

    def default_tag
      dir = ::Rails.root
      name = File.basename(dir)
      # Capistrano release directory
      if name.to_i != 0 && prevdir = File.dirname(dir)
        if File.basename(prevdir) == 'releases'
          return File.basename(File.dirname(prevdir))
        end
      end
      name
    end

    def check_required_keys!
      required_keys = [:redis_host, :client_name, :namespace, :listen_to]
      return if required_keys.all? { |k| config[k] }
      logger.info '======================================================================'
      logger.info '  Tincan needs :redis_host, :client_name, :namespace, and :listen_to'
      logger.info '  defined in config/tincan.yml.'
      logger.info '======================================================================'
      exit 1
    end

    def validate!
      return if File.exist?(config[:require])
      return if File.directory?(config[:require]) &&
                File.exist?("#{config[:require]}/config/application.rb")
      logger.info '=================================================='
      logger.info '  Please point tincan to a Rails 3/4 application'
      logger.info '  to load your receiver with -r [DIR|FILE].'
      logger.info '=================================================='
      exit 1
    end

    def parse_options(argv)
      opts = {}

      @parser = OptionParser.new do |o|
        o.on '-d', '--daemon', 'Daemonize process' do |arg|
          opts[:daemon] = arg
        end

        o.on '-e', '--environment ENV', 'Application environment' do |arg|
          opts[:environment] = arg
        end

        o.on '-r', '--require [DIR]', 'Location of Rails application' do |arg|
          opts[:require] = arg
        end

        o.on '-t', '--timeout NUM', 'Shutdown timeout' do |arg|
          opts[:timeout] = Integer(arg)
        end

        o.on '-v', '--verbose', 'Print more verbose output' do |arg|
          opts[:verbose] = arg
        end

        o.on '-L', '--logfile PATH', 'path to writable logfile' do |arg|
          opts[:logfile] = arg
        end

        o.on '-P', '--pidfile PATH', 'path to pidfile' do |arg|
          opts[:pidfile] = arg
        end

        o.on '-V', '--version', 'Print version and exit' do |_|
          puts "Tincan #{Tincan::VERSION}"
          exit 0
        end
      end

      @parser.banner = 'tincan [options]'
      @parser.on_tail '-h', '--help', 'Show help' do
        logger.info @parser
        exit 1
      end
      @parser.parse!(argv)
      opts[:require] ||= '.'
      if File.exist?('config/tincan.yml')
        opts[:config_file] ||= 'config/tincan.yml'
      end
      opts[:logfile] = 'log/tincan.log' if opts[:daemon] && !opts[:logfile]
      opts
    end

    def initialize_logger
      @logger = ::Logger.new(config[:logfile] || STDOUT)
      @logger.level = ::Logger::DEBUG if config[:verbose]
    end

    def write_pid
      path = config[:pidfile] || 'tmp/pids/tincan.pid'
      pidfile = File.expand_path(path)
      File.open(pidfile, 'w') { |f| f.puts ::Process.pid }
    end

    def parse_config(cfile)
      opts = {}
      if File.exist?(cfile)
        opts = YAML.load(ERB.new(IO.read(cfile)).result)
        opts = opts.with_indifferent_access[environment]
      end
      opts
    end
  end
end
