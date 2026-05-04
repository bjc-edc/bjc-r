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
  def get_curr_folder(folder)
    folder.split('/')[-1]
  end

  def get_topic_course(topic, course)
    if not(TOPIC_COURSE.empty?)
      TOPIC_COURSE.each do |item|
        TOPIC_COURSE.delete(item)
      end
    end
    TOPIC_COURSE.push(course) if !TOPIC_COURSE.include?(course)
    TOPIC_COURSE.push(topic) if !TOPIC_COURSE.include?(topic)
  end

  # get the folder or path before the end.
  # Would return programming in bjc-r/cur/programming/hello.html
  def get_prev_folder(f, include_path=false)
    path = f.split("/#{get_curr_folder(f)}")
    folder = path[0].split("/")
    include_path ? path[0] : folder[-1]
  end


  def url_to_path(url, root: ''); end

  def path_to_url(path, root: ''); end

  def generate_url_suffix(topic, unit_folder, course)
    UNIT_FOLDERS.push(unit_folder) if !UNIT_FOLDERS.include?(unit_folder)
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
      <<-HTML
      <!DOCTYPE html>
      <html lang="#{lang}">
        <head>
          <title>#{title}</title>
          <meta charset="utf-8">
          <script type="text/javascript" src="/bjc-r/llab/loader.js"></script>
        <head>
        <body>
          #{contents}
        </body>
      </html>
      HTML
    end
  end
end
