#!/usr/bin/env ruby
# frozen_string_literal: true

# Build a Common Cartridge (.imscc) package for a BJC course.
#
# Usage:
#   ruby cc_export.rb configs/csp.yml --mode iframe
#   ruby cc_export.rb configs/csp.yml --mode copy --out dist/csp-copy.imscc
#   ruby cc_export.rb configs/csp.yml --all
#
# See README.md for the YAML config schema and LMS compatibility notes.

require 'fileutils'
require 'optparse'
require 'pathname'
require 'tmpdir'
require 'yaml'

# Course HTML and curriculum pages contain UTF-8 (em-dashes, accented chars).
# Force UTF-8 so the tool works regardless of the user's LANG setting.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require_relative 'lib/builder'
require_relative 'lib/packager'

module CCExport
  class CLI
    MODES = %w[iframe copy].freeze

    def self.run(argv)
      options = parse(argv)
      config_path = Pathname.new(argv.first || abort_usage)
      raise "Config not found: #{config_path}" unless config_path.file?

      bjc_root = options[:root] || find_bjc_root(config_path)
      config = YAML.load_file(config_path)

      modes = options[:all] ? MODES : [options[:mode] || 'iframe']
      out_dir = options[:out_dir] || config_path.dirname.parent.join('dist')
      base = options[:out_basename] || config['identifier'] || config_path.basename('.yml').to_s

      modes.each do |mode|
        out_file = out_dir.join("#{base}-#{mode}.imscc")
        build_one(config: config, bjc_root: bjc_root, mode: mode, out_file: out_file)
      end
    end

    def self.build_one(config:, bjc_root:, mode:, out_file:)
      puts "Building #{config['title']} [#{mode}]"
      puts "  bjc root: #{bjc_root}"
      puts "  output:   #{out_file}"

      Dir.mktmpdir("cc-export-#{mode}-") do |staging|
        builder = Builder.new(config: config, bjc_root: bjc_root.to_s, mode: mode)
        builder.build_into(staging)
        Packager.write_imscc(staging, out_file.to_s)
      end
      puts "  wrote #{out_file} (#{File.size(out_file)} bytes)"
    end

    def self.parse(argv)
      opts = { mode: 'iframe' }
      parser = OptionParser.new do |o|
        o.banner = 'Usage: ruby cc_export.rb CONFIG [options]'
        o.on('--mode MODE', MODES, "Build mode: #{MODES.join(' | ')} (default: iframe)") { |m| opts[:mode] = m }
        o.on('--all', 'Build both iframe and copy variants') { opts[:all] = true }
        o.on('--out PATH', 'Output .imscc path (overrides default dist/ location)') do |p|
          path = Pathname.new(p)
          opts[:out_dir] = path.dirname
          opts[:out_basename] = path.basename('.imscc').to_s.sub(/-(iframe|copy)\z/, '')
        end
        o.on('--root PATH', 'Path to bjc-r root') { |p| opts[:root] = Pathname.new(p) }
        o.on('-h', '--help') do
          puts o
          exit
        end
      end
      parser.parse!(argv)
      opts
    end

    # Walk upward from the config file looking for the bjc-r directory.
    def self.find_bjc_root(start_path)
      current = Pathname.new(start_path).realpath
      current.ascend do |dir|
        return dir if dir.basename.to_s == 'bjc-r'
      end
      raise 'Could not locate bjc-r root; pass --root explicitly'
    end

    def self.abort_usage
      warn 'Usage: ruby cc_export.rb CONFIG [options]'
      exit 1
    end
  end
end

CCExport::CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
