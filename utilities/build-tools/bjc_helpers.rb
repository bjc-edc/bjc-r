# frozen_string_literal: true

# The curriculum files are UTF-8, but Ruby infers the default encoding from the
# locale, so force UTF-8 to keep the build working in minimal (POSIX) environments.
Encoding.default_external = Encoding::UTF_8

VALID_LANGUAGES = %w[en es de].freeze

module BJCHelpers
  UNIT_FOLDERS = []
  TOPIC_COURSE = []

  def language_ext(lang)
    lang == 'en' ? '' : ".#{lang}"
  end

  # get the folder or file that is the most inner nested
  # Would return hello.html in bjc-r/cur/programming/hello.html
  def get_curr_folder(folder)
    folder.split('/')[-1]
  end

  def get_topic_course(topic, course)
    TOPIC_COURSE.replace([topic, course])
  end

  # get the folder or path before the end.
  # Would return programming in bjc-r/cur/programming/hello.html
  def get_prev_folder(f, include_path=false)
    path = f.split("/#{get_curr_folder(f)}")
    folder = path[0].split('/')
    include_path ? path[0] : folder[-1]
  end

  def url_to_path(url, root: ''); end

  def path_to_url(path, root: ''); end

  def generate_url_suffix(topic, unit_folder, course)
    UNIT_FOLDERS.push(unit_folder) unless UNIT_FOLDERS.include?(unit_folder)
    "?topic=#{topic}/#{unit_folder}&course=#{course}.html&novideo&noassignment"
  end

  # Methods below here are only visible by calling BJCHelpers.X
  class << self
    # TODO: This needs to use a topic model to get the correct sequence.
    def lab_page_number(unit_str)
      list = unit_str.scan(/(\d+)/)
      if list.length != 3
        puts "Error: Invalid unit string format: #{unit_str}"
      end

      if !list[1] || !list[2]
        puts "Error: Could not find lab or page number in unit string: #{unit_str}"
        puts "\t Parsed list: #{list.inspect}"
      end
      # str.scan seems to return a list of lists...
      I18n.t('lab_page', lab_num: list[1][0], page_num: list[2][0])
    end

    def bjc_html_page(lang, title, contents)
      <<-HTML
      <html lang="#{lang}">
        <head>
          <title>#{title}</title>
        </head>
        <body>#{contents}</body>
      </html>
      HTML
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
