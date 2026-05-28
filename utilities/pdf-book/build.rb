#!/usr/bin/env ruby
# frozen_string_literal: true

# Build a course PDF book.
#
# Usage:
#   ruby utilities/pdf-book/build.rb [options]
#
# Options:
#   --course=NAME         course file under course/ (default: bjc4nyc)
#   --language=LANG       en|es (default: en)
#   --root=PATH           bjc-r root (default: auto-detect)
#   --output=DIR          output directory (default: utilities/pdf-book/out)
#   --max-units=N         limit chapters built (handy for fast iteration)
#   --max-pages=N         limit total pages built
#   --no-pdf              only generate .tex, skip latex run
#   --engine=BIN          latex engine to call (default: pdflatex)
#   --screenshots=N       capture N sample page PNGs after building

require 'optparse'
require 'fileutils'
require 'open3'

require_relative 'lib/book_builder'

opts = {
  course: 'bjc4nyc',
  language: 'en',
  root: nil,
  output: nil,
  max_units: nil,
  max_pages: nil,
  no_pdf: false,
  engine: 'pdflatex',
  screenshots: 0,
}

OptionParser.new do |o|
  o.on('--course=NAME')      { |v| opts[:course] = v }
  o.on('--language=LANG')    { |v| opts[:language] = v }
  o.on('--root=PATH')        { |v| opts[:root] = v }
  o.on('--output=DIR')       { |v| opts[:output] = v }
  o.on('--max-units=N',  Integer) { |v| opts[:max_units] = v }
  o.on('--max-pages=N',  Integer) { |v| opts[:max_pages] = v }
  o.on('--no-pdf')           { opts[:no_pdf] = true }
  o.on('--engine=BIN')       { |v| opts[:engine] = v }
  o.on('--screenshots=N', Integer) { |v| opts[:screenshots] = v }
end.parse!

# Detect bjc-r root: this script lives at bjc-r/utilities/pdf-book/build.rb
opts[:root]   ||= File.expand_path('../..', __dir__)
opts[:output] ||= File.expand_path('out', __dir__)

warn "Building #{opts[:course]} (#{opts[:language]}) from #{opts[:root]}"
warn "Output:  #{opts[:output]}"

builder = BookBuilder.new(
  root: opts[:root],
  course: opts[:course],
  language: opts[:language],
  output_dir: opts[:output],
  max_units: opts[:max_units],
  max_pages: opts[:max_pages],
)
builder.build

warn ''
warn "Missing pages:  #{builder.missing_pages.size}"
warn "Missing images: #{builder.missing_images.size} unique"
warn "Warnings:       #{builder.warnings.size}"
File.write(
  File.join(opts[:output], 'build-report.txt'),
  ([
    "Course: #{opts[:course]} (#{opts[:language]})",
    "Missing pages (#{builder.missing_pages.size}):",
    *builder.missing_pages.first(50).map { |p| "  - #{p}" },
    "",
    "Missing images (#{builder.missing_images.size}):",
    *builder.missing_images.first(50).map { |p| "  - #{p}" },
    "",
    "Warnings (#{builder.warnings.size}):",
    *builder.warnings.first(50).map { |p| "  - #{p}" },
  ]).join("\n")
)

exit 0 if opts[:no_pdf]

warn ''
warn "Running #{opts[:engine]} + makeindex (3 latex passes)..."

def run_latex(engine, output_dir, tex_path, pass_label)
  warn "  #{pass_label}..."
  cmd = [engine, '-interaction=nonstopmode', '-halt-on-error',
         '-output-directory', output_dir, tex_path]
  out, status = Open3.capture2e(*cmd)
  log_path = File.join(output_dir, 'latex.log')
  File.write(log_path, out)
  unless status.success?
    warn "  LaTeX failed (#{pass_label}). Last 60 lines of output:"
    out.lines.last(60).each { |l| warn "    #{l.chomp}" }
    warn "Full output: #{log_path}"
    exit 1
  end
end

# Pass 1: emit .toc, .aux, .idx
run_latex(opts[:engine], opts[:output], builder.master_tex_path, 'latex pass 1')

# makeindex: .idx -> .ind. TeX Live ships with openout_any=p, which
# blocks writes to absolute paths, so cd into the output dir first.
idx_path = File.join(opts[:output], 'book.idx')
if File.exist?(idx_path)
  warn '  makeindex...'
  mi_out, mi_status = Open3.capture2e('makeindex', 'book.idx', chdir: opts[:output])
  File.write(File.join(opts[:output], 'makeindex.log'), mi_out)
  warn '  makeindex failed (continuing without index)' unless mi_status.success?
end

# Pass 2: picks up .ind + .toc
run_latex(opts[:engine], opts[:output], builder.master_tex_path, 'latex pass 2')
# Pass 3: settles cross-references and TOC page numbers
run_latex(opts[:engine], opts[:output], builder.master_tex_path, 'latex pass 3')

pdf_path = File.join(opts[:output], 'book.pdf')
if File.exist?(pdf_path)
  size = File.size(pdf_path)
  warn ''
  warn "PDF built: #{pdf_path} (#{size / 1024} KB)"
end

if opts[:screenshots] > 0 && File.exist?(pdf_path)
  warn "Capturing #{opts[:screenshots]} screenshots..."
  shots_dir = File.join(opts[:output], 'screenshots')
  FileUtils.mkdir_p(shots_dir)
  shots_prefix = File.join(shots_dir, 'page')
  cmd = ['pdftoppm', '-png', '-r', '120',
         '-f', '1', '-l', opts[:screenshots].to_s,
         pdf_path, shots_prefix]
  out, status = Open3.capture2e(*cmd)
  unless status.success?
    warn "pdftoppm failed: #{out}"
  else
    warn "Screenshots in #{shots_dir}"
  end
end
