# frozen_string_literal: true

VALID_LANGUAGES = %w[en es de].freeze
TEMP_FOLDER = 'review'

module BJCHelpers
  UNIT_FOLDERS = []
  TOPIC_COURSE = []

  def language_ext(lang)
    lang == 'en' ? '' : ".#{lang}"
  end

  # get the folder or file that is the most inner nested
  # Would return hello.html in bjc-r/cur/programming/hello.html
  def get_curr_folder(f)
    folder = f.split('/')
    folder[-1]
  end

  def get_topic_course(topic, course)
    unless TOPIC_COURSE.empty?
      TOPIC_COURSE.each do |item|
        TOPIC_COURSE.delete(item)
      end
    end
    TOPIC_COURSE.push(course) unless TOPIC_COURSE.include?(course)
    TOPIC_COURSE.push(topic) unless TOPIC_COURSE.include?(topic)
  end

  # get the folder or path before the end. Would return programming in bjc-r/cur/programming/hello.html
  def get_prev_folder(f, include_path = false)
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
      puts "Error: Invalid unit string format: #{unit_str}" if list.length != 3
      # str.scan seems to return a list of lists...
      I18n.t('lab_page', lab_num: list[1][0], page_num: list[2][0])
    end

    def summary_page_prefix(lang, title)
      <<~HTML
        <!DOCTYPE html>
        <html lang="#{lang}">
          <head>
            <title>#{title}</title>
            <meta charset="utf-8">
            <script type="text/javascript" src="/bjc-r/llab/loader.js"></script>
          </head>
          <body>
            <a style="position: fixed; float: right;"
              class="btn btn-primary btn-lg" href="#top">#{I18n.t('back_to_top')}</a>
      HTML
    end

    def summary_page_suffix
      <<~HTML
          </body>
        </html>
      HTML
    end

    def summary_page_template(lang, title, contents)
      prefix = summary_page_prefix(lang, title)
      "#{prefix}#{contents}#{summary_page_suffix}"
    end
  end
end
