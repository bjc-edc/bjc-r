# frozen_string_literal: true

require 'nokogiri'

module CCExport
  # Reads a curriculum HTML page once and answers questions about it:
  #
  #   - `quiz?` — does the page contain any `<div class="assessment-data">`?
  #   - `student_work?` — does the page contain any `<div class="forYouToDo">`?
  #   - `title` — best human-readable title (h2 → <title> → fallback)
  #
  # Pages are read lazily and cached per absolute path so the cartridge build
  # touches each file at most once even when the same URL is referenced from
  # multiple topic files (e.g. summary pages).
  class PageInspector
    Info = Struct.new(:quiz, :student_work, :title, :raw_html, keyword_init: true) do
      alias_method :quiz?, :quiz
      alias_method :student_work?, :student_work
    end

    def initialize(bjc_root)
      @bjc_root = bjc_root
      @cache = {}
      @missing = {}
    end

    # `url` may be /bjc-r/-rooted, relative to bjc-r, or absolute. Returns
    # Info, or nil when the file doesn't exist on disk.
    def info_for(url)
      rel = relativize(url)
      return nil if rel.nil?

      @cache.fetch(rel) do
        full = File.join(@bjc_root, rel)
        next (@missing[rel] = true) && nil unless File.file?(full)

        html = File.read(full, mode: 'r:UTF-8', invalid: :replace, undef: :replace)
        @cache[rel] = parse_info(html)
      end
    end

    private

    def relativize(url)
      return nil if url.nil? || url.empty?
      return nil unless url.start_with?('/bjc-r/') || url.start_with?('bjc-r/') || !url.start_with?('/')
      return nil if url.match?(%r{\Ahttps?://})

      url.sub(%r{\A/?bjc-r/}, '')
    end

    def parse_info(html)
      doc = Nokogiri::HTML5(html)
      Info.new(
        quiz: doc.at_css('div.assessment-data') ? true : false,
        student_work: doc.at_css('div.forYouToDo') ? true : false,
        title: best_title(doc),
        raw_html: html
      )
    end

    def best_title(doc)
      h2 = doc.at_css('body h2')&.text&.strip
      return h2 unless h2.nil? || h2.empty?

      title = doc.at_css('head > title')&.text&.strip
      return title unless title.nil? || title.empty?

      nil
    end
  end
end
