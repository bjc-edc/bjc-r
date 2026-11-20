# frozen_string_literal: true

require 'cgi/escape'
require 'fileutils'
require 'i18n'
require 'nokogiri'
require 'uri'

require_relative 'bjc_helpers'
require_relative 'course_manifest'
require_relative 'page'
require_relative 'topic'

# Compiles the position-independent source of a course (src/<id>/) into the
# files llab already knows how to serve:
#
#   course/<id>.html          the course page, one link per unit
#   topic/<id>/<unit>.topic   the unit's topic file, with units and labs numbered
#   <id>/**/*.html            the pages, with numbered titles and links that
#                             carry the course's ?topic=&course= context
#
# Source pages never state their own position. A page's <title> and every
# reference to it are generated from the manifest and the topic files, so
# reordering a unit is an edit to one topic file. A link to a page that is not
# in the course fails the build instead of reaching readers.
#
# Nothing is written until the whole course has compiled without errors.
class CourseCompiler
  # Raised when a course cannot be compiled. `problems` lists every error found,
  # not just the first, so one run is enough to see all of them.
  class CompileError < StandardError
    attr_reader :problems

    def initialize(problems)
      @problems = problems
      list = problems.map { |problem| "  - #{problem}" }.join("\n")
      super("#{problems.length} problem(s) stopped the build:\n#{list}")
    end
  end

  Unit = Struct.new(:number, :file, :topic, :name, :lab_numbers)

  SITE_ROOT = BJCHelpers::SITE_ROOT
  RESOURCE_LINE = /\A\s*(?:#{BJCTopic::RESOURCES_KEYWORDS.join('|')}):/
  HEADING_LINE = /\A(\s*(?:#{BJCTopic::HEADINGS_KEYWORDS.join('|')}):\s*)(.*?)\s*\z/
  TITLE_LINE = /\A(\s*title:\s*)(.*?)\s*\z/
  # "mailto:", "https:", "javascript:" ... and protocol-relative "//host/".
  EXTERNAL_URL = %r{\A(?:[a-z][a-z0-9+.-]*:|//)}i
  # The attribute that asks the compiler to write a link's text.
  REFERENCE_ATTRIBUTE = 'data-page-ref'

  attr_reader :manifest, :pages, :units, :warnings, :stats

  # root: the checkout, which holds the shared files (/bjc-r/img/, /bjc-r/prog/).
  # out:  the folder that stands for /bjc-r/ in the compiled site.
  def initialize(root:, manifest:, out:)
    @root = root
    @manifest = manifest
    @out = out
    reset
  end

  # Builds every output file in memory, from whatever the source holds now.
  # Raises CompileError, having written nothing, if the course has a problem.
  def compile
    reset
    I18n.with_locale(manifest.language) do
      load_units
      load_listed_pages
      load_unlisted_pages
      pages.each { |page| @files[output_path(page.url)] = compile_page(page) }
      units.each { |unit| @files[topic_output_path(unit)] = compiled_topic(unit) }
      @files[File.join(@out, 'course', manifest.course_file)] = course_page
      stage_other_files
    end
    raise CompileError, @errors unless @errors.empty?

    self
  end

  # The compiled files, output path => contents.
  def files
    @files.dup
  end

  def write
    remove_previous_output
    @files.each do |path, contents|
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, contents)
    end
    @files.length
  end

  private

  def reset
    @errors = []
    @warnings = []
    @files = {}
    @pages = []
    @pages_by_url = {}
    @stats = Hash.new(0)
  end

  ##### Loading the course

  def load_units
    @units = manifest.units.each_with_index.filter_map do |file, index|
      path = File.join(manifest.source_dir, file)
      next error("course.yml lists #{file}, which does not exist") unless File.file?(path)

      topic = BJCTopic.new(path, course: manifest.id, language: manifest.language)
      Unit.new(index + 1, file, topic, topic.title.to_s.strip, {})
    end
  end

  # Pages that a topic file lists get a unit, lab, and page number.
  def load_listed_pages
    units.each do |unit|
      unit.topic.iterate_curriculum_pages do |entry|
        remember_lab(unit, entry)
        # A shared or external page: the topic file passes it through untouched.
        next unless course_relative?(entry[:path])

        source = File.join(manifest.source_dir, entry[:path])
        next error("#{unit.file} lists #{entry[:path]}, which does not exist") unless File.file?(source)

        add_page(BJCPage.new(source_path: source, url: "#{manifest.url_root}/#{entry[:path]}",
                             name: entry[:title], position: position_of(unit, entry)))
      end
    end
  end

  # Pages no topic file lists (a hints page, say) are still part of the course.
  # They are compiled, but have no number and no place in the navigation.
  def load_unlisted_pages
    source_files('*.html').each do |source|
      url = "#{manifest.url_root}/#{relative_source_path(source)}"
      next if @pages_by_url.key?(url)

      add_page(BJCPage.new(source_path: source, url: url))
      @stats[:unlisted_pages] += 1
    end
  end

  def add_page(page)
    return error("#{label(page)} is listed more than once") if @pages_by_url.key?(page.url)

    @pages << page
    @pages_by_url[page.url] = page
  end

  def position_of(unit, entry)
    { unit: unit.number, lab: entry[:lab_number], page: entry[:page_number], lab_name: entry[:lab],
      topic_reference: topic_reference(unit) }
  end

  # Topic files are rewritten line by line, so remember each lab's number by
  # the text of its heading.
  def remember_lab(unit, entry)
    known = unit.lab_numbers[entry[:lab]]
    error("#{unit.file} has two labs called \"#{entry[:lab]}\"") if known && known != entry[:lab_number]
    unit.lab_numbers[entry[:lab]] = entry[:lab_number]
  end

  ##### Pages

  def compile_page(page)
    document = page.document
    write_title(document, page) if page.listed?
    document.css('a[href]').each { |link| compile_link(link, page) }
    document.css('[src]').each { |node| check_shared_file(node['src'], page) }
    @stats[:pages] += 1
    document.to_html
  end

  def write_title(document, page)
    title = document.at_css('head title') || document.at_css('head').add_child('<title></title>').first
    title.content = page.numbered_title
  end

  def compile_link(link, page)
    href = link['href'].to_s.strip
    return if href.empty? || href.start_with?('#') || href.match?(EXTERNAL_URL)

    path, query, fragment = split_url(href)
    path = File.expand_path(path, File.dirname(page.url)) unless path.start_with?('/')
    if path.start_with?("#{manifest.url_root}/")
      compile_course_link(link, page, path, query, fragment)
    elsif link.key?(REFERENCE_ATTRIBUTE)
      error("#{label(page)}: #{REFERENCE_ATTRIBUTE} on a link to #{path}, which is outside this course")
    else
      check_shared_file(path, page)
    end
  end

  # A link to another page of this course. The page it names must exist; if a
  # topic file lists that page, the link is given the context llab needs to
  # show the right menu, Back and Next buttons, and progress.
  def compile_course_link(link, page, path, query, fragment)
    target = @pages_by_url[path]
    if target&.listed?
      return error("#{label(page)}: the link to #{path} hard-codes \"#{query}\"; the compiler adds it") if query

      link['href'] = "#{path}#{context(target)}#{fragment}"
      @stats[:links] += 1
      write_reference(link, target) if link.key?(REFERENCE_ATTRIBUTE)
    elsif link.key?(REFERENCE_ATTRIBUTE)
      error("#{label(page)}: #{REFERENCE_ATTRIBUTE} needs a page that a topic file lists, but links to #{path}")
    elsif target
      link['href'] = "#{path}#{query}#{fragment}"
    elsif generated_page?(path)
      link['href'] = "#{path}?course=#{manifest.course_file}#{fragment}"
    else
      error("#{label(page)}: links to #{path}, which is not a page of this course")
    end
  end

  # <a href="..." data-page-ref></a> becomes
  # <a href="...">Unit 1 Lab 2 Page 3: Customizing and Debugging</a>.
  # data-page-ref="short" leaves out the unit.
  def write_reference(link, target)
    short = link[REFERENCE_ATTRIBUTE] == 'short'
    link.inner_html = target.reference(short: short)
    link['title'] = target.plain_reference(short: short)
    link.remove_attribute(REFERENCE_ATTRIBUTE)
    @stats[:references] += 1
  end

  def context(page)
    "?topic=#{page.topic_reference}&course=#{manifest.course_file}"
  end

  # The summary pages the existing generators add to a compiled course.
  def generated_page?(path)
    relative = path.delete_prefix("#{manifest.url_root}/")
    relative.match?(/\Avocab-index(\.\w\w)?\.html\z/) || BJCTopic::SUMMARY_URLS.any? { |pattern| relative.match?(pattern) }
  end

  # Images, Snap! projects, and PDFs are shared by every course and stay in the
  # checkout. A missing one is reported, but does not stop the build.
  def check_shared_file(url, page)
    path, = split_url(url.to_s.strip)
    return unless path.start_with?("#{SITE_ROOT}/")
    return if path.start_with?("#{manifest.url_root}/")

    file = File.join(@root, URI.decode_uri_component(path.delete_prefix(SITE_ROOT)))
    @warnings << "#{label(page)}: #{path} does not exist" unless File.exist?(file)
  end

  # "/a/b.html?x=1#top" => ["/a/b.html", "?x=1", "#top"]
  def split_url(url)
    rest, hash, fragment = url.partition('#')
    path, mark, query = rest.partition('?')
    [path, (mark + query unless mark.empty?), (hash + fragment unless hash.empty?)]
  end

  ##### Topic files and the course page

  # The source topic file with its unit and labs numbered and its pages given
  # the URLs they are served from. Everything else passes through untouched.
  def compiled_topic(unit)
    File.readlines(File.join(manifest.source_dir, unit.file)).map do |line|
      text = line.chomp
      if (title = text.match(TITLE_LINE))
        "#{title[1]}#{numbered_unit(unit, title[2])}\n"
      elsif text.match?(RESOURCE_LINE)
        text.sub(/\[([^\]]+)\]/) { "[#{served_url(Regexp.last_match(1).strip)}]" } << "\n"
      elsif (heading = text.match(HEADING_LINE)) && unit.lab_numbers.key?(heading[2])
        "#{heading[1]}#{I18n.t('lab_heading', lab: unit.lab_numbers[heading[2]], name: heading[2])}\n"
      else
        line
      end
    end.join
  end

  def course_page
    links = units.map do |unit|
      name = numbered_unit(unit, unit.name)
      href = "#{SITE_ROOT}/topic/topic.html?topic=#{topic_reference(unit)}"
      %(      <div class="topic_link"><a href="#{href}" title="#{CGI.escapeHTML(name)}">#{name}</a></div>)
    end
    <<~HTML
      <!DOCTYPE html>
      <html lang="#{manifest.language}">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>#{CGI.escapeHTML(manifest.title)}</title>
          <script type="text/javascript" src="#{SITE_ROOT}/llab/loader.js"></script>
        </head>
        <body>
          <h2>#{CGI.escapeHTML(manifest.title)}</h2>
          <div class="topic_container">
      #{links.join("\n")}
          </div>
        </body>
      </html>
    HTML
  end

  def numbered_unit(unit, name)
    "#{I18n.t('unit', num: unit.number)}: #{name}"
  end

  def served_url(url)
    course_relative?(url) ? "#{manifest.url_root}/#{url}" : url
  end

  def topic_reference(unit)
    "#{manifest.topic_folder}/#{unit.file}"
  end

  ##### Files

  # Anything else in the source folder (an image kept beside its page, say) is
  # copied as it is.
  def stage_other_files
    source_files('*').each do |source|
      next if File.directory?(source) || source.end_with?('.html', '.topic')
      next if File.basename(source) == CourseManifest::FILE_NAME

      @files[output_path("#{manifest.url_root}/#{relative_source_path(source)}")] = File.binread(source)
    end
  end

  def source_files(pattern)
    Dir.glob(File.join(manifest.source_dir, '**', pattern))
  end

  def relative_source_path(source)
    source.delete_prefix("#{manifest.source_dir}/")
  end

  def course_relative?(url)
    !url.start_with?('/') && !url.match?(EXTERNAL_URL)
  end

  def output_path(url)
    File.join(@out, url.delete_prefix(SITE_ROOT))
  end

  def topic_output_path(unit)
    File.join(@out, 'topic', manifest.topic_folder, unit.file)
  end

  # Pages removed from the source should not linger in the compiled site. When
  # the output folder is the checkout itself there is no telling compiled files
  # from authored ones, so nothing is removed.
  def remove_previous_output
    return if File.expand_path(@out) == File.expand_path(@root)

    FileUtils.rm_rf([File.join(@out, manifest.id), File.join(@out, 'topic', manifest.topic_folder)])
  end

  def label(page)
    page.source_path.delete_prefix("#{@root}/")
  end

  def error(message)
    @errors << message
    nil
  end
end
