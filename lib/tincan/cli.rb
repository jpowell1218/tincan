$stdout.sync = true

require 'yaml'
require 'erb'
require 'singleton'
require 'optparse'
require 'fileutils'
require 'logger'

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

    def initialize
      @code = nil
    end

    def parse(args = ARGV)
      @code = nil

      setup_options(args)
      initialize_logger
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
          puts "Signal #{sig} not supported"
        end
      end

      logger.info "Running in #{RUBY_DESCRIPTION}"

      unless options[:daemon]
        logger.info 'Starting processing, hit Ctrl-C to stop'
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
        receiver.listen

        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          handle_signal(signal)
        end
      rescue Interrupt
        logger.info 'Shutting down'
        # launcher.stop
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
      Tincan.logger.debug "Got #{sig} signal"
      case sig
      when 'INT'
        fail Interrupt
      when 'TERM'
        fail Interrupt
      when 'USR1'
        Tincan.logger.info 'Received USR1, no longer accepting new work'
        fail Interrupt
        # receiver.stop
      when 'USR2'
        if Tincan.options[:logfile]
          Tincan.logger.info 'Received USR2, reopening log file'
          Tincan::Logging.reopen_logs
        end
      when 'TTIN'
        Thread.list.each do |thread|
          label = thread['label']
          Tincan.logger.info "Thread TID-#{thread.object_id.to_s(36)} #{label}"
          if thread.backtrace
            Tincan.logger.info thread.backtrace.join("\n")
          else
            Tincan.logger.info '<no backtrace available>'
          end
        end
      end
    end

    def daemonize
      return unless options[:daemon]

      unless options[:logfile]
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
        File.open(options[:logfile], 'ab') do |f|
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

    def setup_options(args)
      opts = parse_options(args)
      set_environment opts[:environment]
      opts = parse_config(opts[:config_file]).merge(opts) if opts[:config_file]
      opts[:strict] = true if opts[:strict].nil?
      @config = opts
    end

    def boot_system
      ENV['RACK_ENV'] = ENV['RAILS_ENV'] = environment

      unless File.exist?(options[:require])
        fail ArgumentError, "#{options[:require]} does not exist"
      end

      if File.directory?(options[:require])
        require 'rails'
        require File.expand_path("#{options[:require]}/config/environment.rb")
        ::Rails.application.eager_load!
        options[:tag] = default_tag
      else
        require options[:require]
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

    def validate!
      unless File.exist?(options[:require]) ||
             (File.directory?(options[:require]) &&
              !File.exist?("#{options[:require]}/config/application.rb"))
        return
      end
      logger.info '=================================================='
      logger.info '  Please point tincan to a Rails 3/4 application'
      logger.info '  to load your receiver with -r [DIR|FILE].'
      logger.info '=================================================='
      logger.info @parser
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
      if File.exist?('config/tincan.yml')
        opts[:config_file] ||= 'config/tincan.yml'
      end
      opts
    end

    def initialize_logger
      @logger = ::Logger.new(options[:logfile])
      @logger.level = ::Logger::DEBUG if options[:verbose]
    end

    def write_pid
      path = options[:pidfile]
      return unless path
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
