# frozen_string_literal: true

# The curriculum files are UTF-8, but Ruby infers the default encoding from the
# locale, so force UTF-8 to keep the build working in minimal (POSIX) environments.
Encoding.default_external = Encoding::UTF_8

VALID_LANGUAGES = %w[en es de].freeze

module BJCHelpers
  class << self
    # The topic folder and course the build tools are currently generating
    # pages for, e.g. { topic_folder: 'nyc_bjc', course: 'bjc4nyc' }. Used to
    # build the ?topic=&course= parameters of links on generated pages.
    attr_accessor :current_topic
  end
  self.current_topic = {}

  def language_ext(lang)
    lang == 'en' ? '' : ".#{lang}"
  end

  # get the folder or file that is the most inner nested
  # Would return hello.html in bjc-r/cur/programming/hello.html
  def get_curr_folder(folder)
    folder.split('/')[-1]
  end

  def set_current_topic(topic_folder, course)
    BJCHelpers.current_topic = { topic_folder: topic_folder, course: course }
  end

  # get the folder or path before the end.
  # Would return programming in bjc-r/cur/programming/hello.html
  def get_prev_folder(f, include_path: false)
    path = f.split("/#{get_curr_folder(f)}")
    folder = path[0].split('/')
    include_path ? path[0] : folder[-1]
  end

  def generate_url_suffix(topic_folder, topic_file, course)
    "?topic=#{topic_folder}/#{topic_file}&course=#{course}.html"
  end

  # The helpers below are shared by the summary generators (vocab, self-check,
  # "@ Work"). Each tracks the curriculum page it is currently reading in
  # @currUnit, taken from the page's <title>, which looks like
  # "Unit 3 Lab 2: Interactive Pet, Activity 4".

  # "3.2.4" for the title above.
  def unit_reference
    @currUnit.scan(/\d+/).join('.')
  end

  # "Lab 2: Interactive Pet" for the title above.
  def currLab
    return if @currUnit.nil?

    @currLab = @currUnit.match(/Lab.+,/).to_s.split(',').join
  end

  # The topic files for the course, without their containing folder.
  # Generated links need the file name to build ?topic= URLs.
  def topic_files_in_course
    @topic_files_in_course ||= @course.list_topics_no_path.filter { |file| file.match(/\d+-\w+/) }
  end

  # The topic file for the unit currently being summarized.
  def get_topic_file
    unit_num = unit_reference[/\d+/].to_s
    topic_files_in_course.find { |file| file.match(unit_num) }
  end

  # The "?topic=...&course=..." suffix that makes a generated link open inside
  # the course navigation.
  def topic_url_suffix
    current = BJCHelpers.current_topic
    generate_url_suffix(current[:topic_folder], get_topic_file, current[:course])
  end

  # Warn when a run rewrote a topic file so the change doesn't get committed by
  # accident. `new_content` is compared against what is still on disk.
  def report_topic_file_change(topic_file_path, new_content)
    return unless File.exist?(topic_file_path)
    return if File.read(topic_file_path) == new_content

    relative_path = topic_file_path.delete_prefix("#{@rootDir}/")
    puts <<~NOTICE
      NOTICE: Build tools modified topic file: #{relative_path}
              Its generated unit review section was updated. Review this file before committing.
    NOTICE
  end

  # Methods below here are only visible by calling BJCHelpers.X
  class << self
    # TODO: This needs to use a topic model to get the correct sequence.
    def lab_page_number(unit_str)
      list = unit_str.scan(/(\d+)/)
      puts "Error: Invalid unit string format: #{unit_str}" if list.length != 3

      if !list[1] || !list[2]
        puts "Error: Could not find lab or page number in unit string: #{unit_str}"
        puts "\t Parsed list: #{list.inspect}"
      end
      # str.scan seems to return a list of lists...
      I18n.t('lab_page', lab_num: list[1][0], page_num: list[2][0])
    end

    def summary_page_template(lang, title, contents)
      "#{summary_page_prefix(lang, title)}#{contents}#{summary_page_suffix}"
    end

    # The shared <head> and opening <body> for all generated summary pages.
    # Content is appended to this, then closed off with summary_page_suffix.
    def summary_page_prefix(lang, title)
      <<~HTML
        <!DOCTYPE html>
        <html lang="#{lang}">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>#{title}</title>
          <script type="text/javascript" src="/bjc-r/llab/loader.js"></script>
          <script type="text/javascript" src="/bjc-r/utilities/gifffer.min.js"></script>
          <script type="text/javascript">window.onload = function() {Gifffer();}</script>
          <link rel="stylesheet" type="text/css" href="/bjc-r/css/bjc-gifffer.css">
        </head>
        <body>
      HTML
    end

    def summary_page_suffix
      "\n</body>\n</html>\n"
    end
  end
end
