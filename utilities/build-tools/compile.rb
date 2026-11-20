#! /usr/bin/env ruby
# frozen_string_literal: true

## Compiles the courses under src/ into a site llab can serve.
## $ bundle exec ruby utilities/build-tools/compile.rb
## $ bundle exec ruby utilities/build-tools/compile.rb --course csp --watch
##
## The compiled files go to _site/bjc-r/, which ./run-server layers over the
## checkout. See utilities/build-tools/README.md.

require 'optparse'
require 'stringio'

require_relative 'main'
require_relative 'course_compiler'

ROOT = File.expand_path('../..', __dir__)

# Keep progress and problems in order when the output is piped or logged.
$stdout.sync = true

options = { out: File.join(ROOT, '_site', 'bjc-r'), summaries: true, watch: false }
OptionParser.new do |parser|
  parser.banner = 'Usage: compile.rb [options]'
  parser.on('--course ID', 'compile only this course (default: every src/*/course.yml)') { |id| options[:course] = id }
  parser.on('--out DIR', 'where to write the site (default: _site/bjc-r)') do |dir|
    options[:out] = File.expand_path(dir)
  end
  parser.on('--no-summaries', 'skip the vocabulary and self-check pages') { options[:summaries] = false }
  parser.on('--watch', 'recompile whenever a file under src/ changes') { options[:watch] = true }
end.parse!

# The existing generators, unchanged, run over the compiled course: its pages
# carry the same numbered titles they read from pages today. They report every
# page they visit and change the working directory, so both are put back.
def build_summaries(manifest, out)
  original_directory = Dir.pwd
  log = StringIO.new
  $stdout = log
  Main.new(root: out, content: manifest.id, course: manifest.id, language: manifest.language).Main
  $stdout = STDOUT
  puts "#{manifest.id}: #{log.string[/Wrote \d+ files/].to_s.downcase} by the summary generators"
rescue StandardError
  $stdout = STDOUT
  puts log.string
  raise
ensure
  $stdout = STDOUT
  Dir.chdir(original_directory)
end

def report(compiler, written, seconds)
  stats = compiler.stats
  puts "#{compiler.manifest.id}: #{stats[:pages]} pages (#{stats[:unlisted_pages]} not in a topic file), " \
       "#{stats[:links]} links given course context, #{stats[:references]} references written, " \
       "#{written} files in #{seconds.round(2)}s"
  compiler.warnings.each { |warning| puts "  warning: #{warning}" }
end

# Returns true when every course compiled.
def build(options)
  manifests = CourseManifest.discover(ROOT)
  manifests.select! { |manifest| manifest.id == options[:course] } if options[:course]
  abort "No course to compile under #{CourseManifest::SOURCE_FOLDER}/" if manifests.empty?

  manifests.map do |manifest|
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    compiler = CourseCompiler.new(root: ROOT, manifest: manifest, out: options[:out]).compile
    written = compiler.write
    report(compiler, written, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
    build_summaries(manifest, options[:out]) if options[:summaries]
    true
  rescue CourseCompiler::CompileError => e
    warn "#{manifest.id}: #{e.message}"
    false
  end.all?
end

def source_state
  Dir.glob(File.join(ROOT, CourseManifest::SOURCE_FOLDER, '**', '*')).to_h { |file| [file, File.mtime(file)] }
end

ok = build(options)
exit(ok ? 0 : 1) unless options[:watch]

puts "Watching #{CourseManifest::SOURCE_FOLDER}/ -- Control-C to stop."
last_state = source_state
begin
  loop do
    sleep 0.5
    state = source_state
    next if state == last_state

    last_state = state
    build(options)
  end
rescue Interrupt
  puts "\nStopped."
end
