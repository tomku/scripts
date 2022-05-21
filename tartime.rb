#!/usr/bin/env ruby
#
# frozen_string_literal: true

require 'bundler/inline'
require 'optparse'
require 'find'
require 'zlib'
require 'time'

gemfile do
  source 'https://rubygems.org/'
  gem 'minitar'
end

# Creates timestamped, compressed backup tarballs of a source folder to a
# destination folder.
module TarTime
  # Parses, validates and stores the source and destination paths
  class Options
    # Source directory, must exist and be readable.
    attr_accessor :source
    # Destination directory, can be created but must not be an existing file.
    attr_accessor :dest

    private

    def check_required
      required = %w[source dest]
      vars = instance_variables.map { |v| v.name.delete_prefix('@') }
      need = required - vars
      raise("missing required flags: #{need.join(', ')}") unless need.empty?
    end

    def check_exists
      raise('source must be an existing directory') unless @source.directory?
      raise('destination must not be an existing file') if @dest.file?
    end

    def make_parser
      OptionParser.new do |parser|
        setup_help(parser)
        setup_args(parser)
      end
    end

    def setup_help(parser)
      parser.program_name = 'tartime'
      parser.banner = "Usage: #{parser.program_name} source destination"
      parser.on('-h', '--help', 'Prints this help') do
        puts parser.help
        exit
      end
    end

    def setup_args(parser)
      parser.on('-s SRC', '--source SRC',
                'Back up files located at SRC', String) do |src|
        @source = Pathname.new(src)
      end
      parser.on('-d DEST', '--dest DEST',
                'Save timestamped backup tarball to DEST', String) do |dest|
        @dest = Pathname.new(dest)
      end
    end

    public

    # Parses flags from argv and sets source and destination if they are valid
    def initialize
      make_parser.parse!

      check_required
      check_exists
    end
  end

  # Main entrypoint for command-line useage.
  class App
    # Parses command line arguments out of +argv+ and creates a backup tarball if
    # +source+ is a folder and +dest+ either doesn't exist or is a folder..
    def initialize
      opts = Options.new
      TarTime.ensure_dir(opts.dest)
      fname = TarTime.backup_filename(opts.source)
      raise('target backup filename already exists') if fname.exist?

      TarTime.relative_tar(opts.source, opts.dest + fname)
    end
  end

  # Repeatedly prints +prompt+ until the user answers with 'y', 'Y', 'n' or 'N'.
  def self.y_or_n(prompt)
    print prompt
    loop do
      case gets.strip
      when /^[yY]$/
        break true
      when /^[nN]$/
        break false
      end
      print prompt
    end
  end

  # Checks that +dir+ exists, offers to create if it does not, and crashes if
  # we can't create it.
  def self.ensure_dir(dir)
    return if dir.directory?

    prompt = "create #{dir} and any missing parent directories? (y/n) "
    raise('destination must either exist or be created') unless y_or_n(prompt)

    FileUtils.mkdir_p dir
  end

  # Formats Time object +time+ as ISO 8601 and sanitize the result so it's
  # a valid path on most filesystems.
  def self.timestamp_pathsafe(time)
    time.gmtime.iso8601.gsub(/:/, '-')
  end

  # Generates a backup filename for a given +source+ path, assuming the backup is
  # happening right now.
  def self.backup_filename(source)
    Pathname.new("#{source.basename}-#{timestamp_pathsafe(Time.new)}.tar.gz")
  end

  # Creates a tarball +dest+ of a given +src+ directory using relative paths such
  # that it will unpack to one directory containing the contents of +src+.
  def self.relative_tar(src, dest)
    base = src.parent
    files = Find.find(src).map { |f| Pathname.new(f).relative_path_from(base) }
    FileUtils.cd(base) do
      Zlib::GzipWriter.open(dest) do |gzip|
        Minitar.open(gzip, 'w') do |tar|
          files.each { |f| Minitar.pack_file(f.to_s, tar) }
        end
      end
    end
  end
end

TarTime::App.new if __FILE__ == $PROGRAM_NAME
