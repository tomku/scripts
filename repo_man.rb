#!/usr/bin/env ruby

# frozen_string_literal: true

require 'optparse'
require 'pathname'
require 'fileutils'

module RepoMan
  # Holds command-line options for the app.
  class Options
    attr_reader :root

    def setup_parser(parser)
      parser.program_name = 'repo_man'
      parser.banner = "Usage: #{parser.program_name} --root dir"
    end

    def setup_args(parser)
      parser.on('-h', '--help', 'Prints this help') do
        puts parser.help
        exit
      end

      parser.on('--root ROOT', 'Look for repos to update in ROOT', String) do |root|
        @root = Pathname.new(root).realpath
      end
    end

    def ensure_root
      raise('root must exist') unless @root.exist?
      raise('root must be a directory') unless @root.directory?
    end

    def initialize
      OptionParser.new do |parser|
        setup_parser(parser)
        setup_args(parser)
      end.parse!
      ensure_root
    end
  end

  # Main entrypoint for command-line usage.
  class App
    def child_dirs
      @opts.root.children.select(&:directory?).sort
    end

    def pull_git
      system('git pull --ff-only', exception: true)
      modules = Pathname.getwd / 'gitmodules'
      system('git submodule update --init', exception: true) if modules.file?
      system('git remote prune origin', exception: true)
      system('git remote set-head -a origin', exception: true)
      system('git gc', exception: true)
    end

    def pull_hg
      system('hg update', exception: true)
    end

    def pull_fossil
      system('fossil pull', exception: true)
    end

    def detect_and_pull(dir)
      FileUtils.cd(dir, verbose: true) do
        if (dir / '.git').directory?
          pull_git
        elsif (dir / '.hg').directory?
          pull_hg
        elsif (dir / '.fossil-settings').directory?
          pull_fossil
        end
      end
    end

    def print_errors(errs)
      puts 'errors:'
      errs.each do |broken|
        puts "- \e[31m#{broken}\e[0m"
      end
    end

    # Parses +argv+ and updates all version control repositories
    # located directly below the given root directory.
    def initialize
      @opts = Options.new
      errs = []
      child_dirs.each do |dir|
        detect_and_pull(dir)
      rescue StandardError => _e
        errs << dir
      end

      print_errors(errs) unless errs.empty?
    end
  end
end

RepoMan::App.new if __FILE__ == $PROGRAM_NAME
