# frozen_string_literal: true

require 'fileutils'
require 'nokogiri'
require 'open3'

# Load the existing build-tools so we can reuse BJCCourse / BJCTopic
# instead of duplicating the topic-file parser.
BUILD_TOOLS = File.expand_path('../../build-tools', __dir__)
$LOAD_PATH.unshift(BUILD_TOOLS)

require 'i18n'
I18n.load_path = Dir["#{BUILD_TOOLS}/*.yml"]
I18n.backend.load_translations

require 'course'
require 'topic'

require_relative 'latex_renderer'

# BookBuilder walks a single BJC course (e.g. bjc4nyc) and assembles a
# linked, hyperlinked LaTeX book:
#
#   Course   -> overall document
#   Unit     -> \chapter (one per topic file in the course)
#   Lab      -> \section (one per `heading:` in the topic file)
#   Page     -> \subsection (one per `resource:` / `quiz:` / `reading:` line)
#
# pandoc converts each page's HTML to a LaTeX fragment; the builder wraps
# it in the right sectioning level. hyperref + the standard \tableofcontents
# give us a clickable TOC and PDF outline.
class BookBuilder
  DEFAULT_LANGUAGE = 'en'

  # Headings on the topic file we want to *skip* as labs. The summary
  # heading at the bottom of each unit is rendered separately at the
  # end of the chapter.
  SKIP_HEADINGS = [
    /^Unit\s*\d+\s*Review/i,
    /^Unidad\s*\d+\s*Revision/i,
  ].freeze

  attr_reader :course_name, :language, :missing_images, :missing_pages, :warnings

  def initialize(root:, course:, language: DEFAULT_LANGUAGE, output_dir:,
                 max_pages: nil, max_units: nil)
    raise '`root` must end with bjc-r' unless root.match?(%r{bjc-r/?$})

    @root = root.chomp('/')
    @course_name = course
    @language = language
    @output_dir = File.expand_path(output_dir)
    @max_pages = max_pages
    @max_units = max_units

    @image_cache_dir = File.join(@output_dir, 'img-cache')
    @renderer = LatexRenderer.new(bjc_root: @root, image_cache_dir: @image_cache_dir)
    @missing_images = []
    @missing_pages = []
    @warnings = []
    @page_count = 0
  end

  def build
    FileUtils.mkdir_p(@output_dir)
    course = BJCCourse.new(root: @root, course: @course_name, language: @language)

    topic_files = unique_topics(course.list_topics)
    topic_files = topic_files.first(@max_units) if @max_units

    chapters_latex = topic_files.each_with_index.map do |topic_path, idx|
      log "[unit #{idx + 1}/#{topic_files.size}] #{topic_path}"
      render_unit(topic_path)
    end

    book_title = guess_book_title(course)
    write_master_tex(book_title, chapters_latex)
    log "Wrote #{master_tex_path}"
  end

  def master_tex_path
    File.join(@output_dir, 'book.tex')
  end

  private

  # `course.list_topics` returns the topic paths with their original order,
  # but the AP-Create-Task topic is currently linked twice in bjc4nyc; keep
  # only the first occurrence so we don't repeat its chapter.
  def unique_topics(topics)
    seen = {}
    topics.reject { |t| seen[t] ? true : (seen[t] = true; false) }
  end

  def render_unit(relative_topic_path)
    full_path = File.join(@root, 'topic', relative_topic_path)
    return "% Missing topic file: #{relative_topic_path}\n" unless File.exist?(full_path)

    topic_source = File.read(full_path, encoding: 'BINARY').force_encoding('UTF-8').scrub('?')
    structure = parse_topic_source(topic_source)

    chapter_title = latex_escape(structure[:title] || File.basename(full_path, '.*'))
    out = +"\n\\chapter{#{chapter_title}}\n"
    out << "\\label{chap:#{slug(structure[:title] || relative_topic_path)}}\n\n"

    structure[:sections].each_with_index do |section, _i|
      next if SKIP_HEADINGS.any? { |re| section[:heading].match?(re) }
      out << render_lab(section)
    end
    out
  end

  def render_lab(section)
    out = +"\n\\section{#{latex_escape(section[:heading])}}\n"
    out << "\\label{sec:#{slug(section[:heading])}}\n\n"

    section[:resources].each do |res|
      next unless res[:url]
      url = res[:url].split('?', 2).first # strip ?topic=... params
      next unless url.start_with?('/bjc-r/')
      out << render_page(url, res[:title])
    end
    out
  end

  def render_page(bjc_url, page_title)
    return '' if @max_pages && @page_count >= @max_pages

    local_path = File.join(@root, bjc_url.sub(%r{^/bjc-r/}, ''))
    unless File.exist?(local_path)
      @missing_pages << bjc_url
      warn "missing page: #{bjc_url}"
      return "\n\\subsection*{#{latex_escape(strip_html(page_title))} (missing)}\n"
    end

    @page_count += 1
    log "    page: #{bjc_url}"

    begin
      latex_body, cleaner = @renderer.render_page(local_path)
    rescue => e
      @warnings << "render error #{bjc_url}: #{e.message}"
      warn "  ! #{e.message}"
      return "\n\\subsection{#{latex_escape(strip_html(page_title))}}\n% render error: #{e.message}\n"
    end

    @missing_images.concat(cleaner.missing_images)

    # Prefer the topic file's title (which is the human-curated lab label)
    # over the H2 the cleaner extracted; falling back to the cleaner
    # title if the topic line is blank.
    title = strip_html(page_title)
    title = cleaner.title if title.empty? && !cleaner.title.empty?

    body = +""
    body << "\n\\subsection{#{latex_escape(title)}}\n"
    body << "\\label{page:#{slug(bjc_url)}}\n\n"
    body << latex_body
    body << "\n"
    body
  end

  # Parse a .topic file into a simple structure:
  # { title: "...", sections: [ { heading: "...", resources: [{title:, url:}] }, ... ] }
  #
  # We re-do this in the builder (rather than reusing BJCTopic.parse)
  # because BJCTopic#get_content drops content after the second colon
  # ("Lab 1: Click Alonzo Game" -> "Lab 1"), which loses the human lab
  # labels we want in the LaTeX section headings.
  def parse_topic_source(src)
    title = nil
    sections = []
    current = nil
    src.split("\n").each do |raw|
      line = strip_topic_comment(raw)
      next if line.empty?

      if line.match?(/^title:/)
        title = line.sub(/^title:\s*/, '').strip
      elsif (m = line.match(/^heading:\s*(.*)$/))
        current = { heading: m[1].strip, resources: [] }
        sections << current
      elsif (m = line.match(/^\s*(resource|quiz|reading|extresource|video|assignment):\s*(.*?)\s*\[(.+?)\]\s*$/))
        next unless current
        current[:resources] << { type: m[1], title: m[2].strip, url: m[3].strip }
      end
    end
    { title: title, sections: sections }
  end

  def strip_topic_comment(s)
    return '' unless s
    s.gsub(/(\s|^)\/\/.*/, '').strip
  end

  def guess_book_title(_course)
    case @course_name
    when 'bjc4nyc' then 'BJC: Computer Science Principles'
    when 'sparks' then 'BJC Sparks: Middle School'
    else "BJC \\textemdash{} #{@course_name}"
    end
  end

  def write_master_tex(book_title, chapters_latex)
    preamble = File.read(File.expand_path('../templates/preamble.tex', __dir__))
    cover    = File.read(File.expand_path('../templates/cover.tex',    __dir__))

    File.open(master_tex_path, 'w') do |f|
      f.write(preamble)
      f.write("\n")
      f.write("\\newcommand{\\BJCCourseTag}{#{latex_escape(@course_name)}}\n")
      f.write("\\newcommand{\\BJCBookTitle}{#{book_title}}\n")
      f.write("\\newcommand{\\BJCBookAuthors}{The BJC Team \\\\ EDC, UC Berkeley}\n")
      f.write(cover)
      f.write(<<~TEX)

        \\hypersetup{
          pdftitle={#{strip_braces(book_title)}},
          pdfauthor={The BJC Team},
          pdfsubject={BJC Course Book},
          pdfkeywords={BJC, AP CSP, Snap!, computer science},
        }

        \\begin{document}
        \\sloppy
        \\frontmatter
        \\bjccoverpage
        \\tableofcontents
        \\mainmatter
        \\pagestyle{plain}

      TEX
      chapters_latex.each { |c| f.write(c) }
      f.write(<<~TEX)

        \\cleardoublepage
        \\phantomsection
        \\printindex
      TEX
      f.write("\n\\end{document}\n")
    end
  end

  def slug(s)
    s.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')[0, 80]
  end

  def latex_escape(s)
    s.to_s
     .gsub('\\', '\\textbackslash{}')
     .gsub('&',  '\\&')
     .gsub('%',  '\\%')
     .gsub('$',  '\\$')
     .gsub('#',  '\\#')
     .gsub('_',  '\\_')
     .gsub('{',  '\\{')
     .gsub('}',  '\\}')
     .gsub('~',  '\\textasciitilde{}')
     .gsub('^',  '\\textasciicircum{}')
  end

  def strip_html(s)
    Nokogiri::HTML.fragment(s.to_s).text.strip
  end

  def strip_braces(s)
    s.gsub(/[{}]/, '')
  end

  def log(msg)
    warn msg
  end
end
