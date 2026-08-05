# frozen_string_literal: true

require 'i18n'

# The curriculum files are UTF-8, but Ruby infers the default encoding from the
# locale, so force UTF-8 to keep the build working in minimal (POSIX) environments.
Encoding.default_external = Encoding::UTF_8

# The build tools' own translations, and nothing else. This used to be
# `Dir['**/*.yml']`, which depends on the working directory and picks up every
# unrelated YAML file under it -- including the couple of thousand that ship
# with the gems once bundler installs into vendor/bundle, one of which is a
# top-level array that I18n refuses to merge.
BJC_TRANSLATIONS = File.expand_path('bjc_translations.yml', __dir__)
I18n.load_path |= [BJC_TRANSLATIONS]
I18n.backend.load_translations(BJC_TRANSLATIONS)

VALID_LANGUAGES = %w[en es de].freeze

module BJCHelpers
  class << self
    # The topic folder and course the build tools are currently generating
    # pages for, e.g. { topic_folder: 'nyc_bjc', course: 'bjc4nyc' }. Used to
    # build the ?topic=&course= parameters of links on generated pages.
    attr_accessor :current_topic
  end
  self.current_topic = {}

  # Where the site is served from. It is also the name of the folder holding
  # the checkout, so mapping a path to a URL is a matter of swapping prefixes.
  SITE_ROOT = '/bjc-r'

  def language_ext(lang)
    lang == 'en' ? '' : ".#{lang}"
  end

  # The folder *containing* the checkout: "/home/me/src" for a checkout at
  # "/home/me/src/bjc-r". delete_suffix, not a regex match, because a parent
  # folder may be called bjc-r too.
  def checkout_root
    @checkout_root ||= @rootDir.delete_suffix('/').delete_suffix(SITE_ROOT)
  end

  # "/bjc-r/cur/programming/x.html" => "<checkout>/bjc-r/cur/programming/x.html"
  def url_to_path(url)
    "#{checkout_root}#{url}"
  end

  # "<checkout>/bjc-r/cur/programming" => "/bjc-r/cur/programming"
  def path_to_url(path)
    path.delete_prefix(checkout_root)
  end

  # The URL of a file in the given folder, which defaults to the folder of the
  # curriculum page currently being read.
  def url_for(file, directory = Dir.getwd)
    "#{path_to_url(directory)}/#{file}"
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

  def generate_url_suffix(topic, unit_folder, course)
    UNIT_FOLDERS.push(unit_folder) if !UNIT_FOLDERS.include?(unit_folder)
    "?topic=#{topic}/#{unit_folder}&course=#{course}.html"
  end

  def report_topic_file_change(topic_file_path, original_content)
    return if File.read(topic_file_path) == original_content

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
