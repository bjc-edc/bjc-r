module BJCHelpers
  UNIT_FOLDERS = []
  TOPIC_COURSE = []

  def language_ext(lang)
    lang == 'en' ? '' : ".#{lang}"
  end

  #get the folder or file that is the most inner nested
  #Would return hello.html in bjc-r/cur/programming/hello.html
  def get_curr_folder(f)
    folder = f.split("/")
    return folder[-1]
  end
  
  def get_topic_course(topic, course)
    TOPIC_COURSE.push(topic) if !TOPIC_COURSE.include?(topic)
    TOPIC_COURSE.push(course) if !TOPIC_COURSE.include?(course)
  end

  #get the folder or path before the end. Would return programming in bjc-r/cur/programming/hello.html
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

  def bjc_html_page(lang, title, contents)
    <<~HTML
    <html lang="#{lang}">
      <head>
        <title>#{title}</title>
      </head>
      <body>#{contents}</body>
    </html>
    HTML
  end
end
