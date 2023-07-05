module BJCHelpers
  def language_ext(lang)
    lang == 'en' ? '' : ".#{lang}"
  end

  def url_to_path(url, root: ''); end

  def path_to_url(path, root: ''); end

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
