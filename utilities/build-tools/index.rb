# frozen_string_literal: true

require 'fileutils'
require 'i18n'

require 'nokogiri'
require 'twitter_cldr'
require 'htmlbeautifier'

require_relative 'vocab'
require_relative 'main'
require_relative 'atwork'

FILE_NAME = 'vocab-index'
# Special case words and terms.
# Contains both English and Spanish terms.
CAPITALS = [
  'IP', 'DDoS', 'SSL', 'TLS', 'TCP', 'AI', 'ADT', 'API',
  'Creative Commons', 'ISPs', 'Commons', 'Creative', 'Boolean',
  # CSP Spanish
  'IA', 'IPA', 'PCT', 'PI', 'Booleano',
  # Sparks
  'SPOF'
].freeze

class Index
  attr_accessor :language, :vocab_url_map, :file_body

  def initialize(path, language = 'en')
    @parentDir = path
    @language = language
    @vocabList = []
  end

  def language_ext
    @language_ext ||= @language == 'en' ? '' : ".#{@language}"
  end

  def index_filename
    "#{FILE_NAME}#{language_ext}.html"
  end

  def vocabList(list)
    @vocabList = list
  end

  def locale_alphabet
    if @language == 'es'
      %w[a b c d e f g h i j k l m n ñ o p q r s t u v w x y z]
    else
      ('a'..'z').to_a
    end
  end

  def alphabet_links(used_letters)
    locale_alphabet.map do |letter|
      if used_letters.include?(letter)
        "<a href=\"##{letter.upcase}\">#{letter.upcase}</a>&nbsp;\n"
      else
        "<span>#{letter.upcase}</span>&nbsp;\n"
      end
    end.join
  end

  def alphabet_index_links(used_letters, output)
    contents = <<-HTML
      <div class="index-letter-link">
        #{alphabet_links(used_letters)}
      </div>
      <div>
        #{output}
      </div>
    HTML

    @file_body ||= ''
    @file_body += contents
  end

  def non_alpha_char?(vocab)
    !(capital?(vocab[0]) or lowercase?(vocab[0]))
  end

  def capital?(char)
    (char.bytes[0] >= 65 and char.bytes[0] <= 90)
  end

  def lowercase?(char)
    (char.bytes[0] >= 97 and char.bytes[0] <= 122)
  end

  # alphabet and letter are lowercase and returned vocab word is upper and then lowercase
  def castCharToEng(vocab)
    TwitterCldr::Collation::Collator.new(@language)
    return vocab unless non_alpha_char?(vocab)

    letter = vocab[0].downcase
    alpha = locale_alphabet.push(letter).localize(@language).sort.to_a
    letter = alpha[alpha.index(letter) + 1]
    letter.upcase if capital?(vocab[0])
    letter.upcase + vocab[1..]
  end

  def generate_html_list
    # Localize using TwitterCldr and sort
    # These terms must match the keys in @vocab_url_map
    terms = @vocabList.localize(@language).sort.to_a.map { |word| word.strip.gsub(': ', '') }
    used_letters = []
    output = "<ul style=\"list-style-type:square\">\n"
    prev_letter = ''
    terms.each do |vocab|
      original_word = vocab
      vocab = vocab.downcase unless keep_Capitalized?(vocab)
      # TODO: Use this but currently broken for ADT, others?
      # vocab = index_downcase(vocab)
      entry_letter = vocab[0].downcase

      # Remove diacritics for indexing if not in locale alphabet
      # Applies to "Índice",
      # but we don't have any ñ words yet that would need to be indexed under ñ.
      entry_letter = I18n.transliterate(entry_letter).downcase unless locale_alphabet.include?(entry_letter)

      if prev_letter != entry_letter
        output += "\n\t\t</li></ol>\n" if used_letters.any?

        prev_letter = entry_letter
        used_letters.push(entry_letter)
        output += <<-HTML
          <li class="index-letter-target" style="list-style-type: none">
            <h2 id="#{entry_letter.upcase}">#{entry_letter.upcase}</h2>
            <ol style="list-style-type: square">
        HTML
      end
      unless @vocab_url_map.key?(original_word)
        puts "Warning: No URL mapping found for vocab word: #{vocab}"
        next
      end
      links = @vocab_url_map[original_word].join(', ')
      output += "\n\t<li>#{vocab} &nbsp; #{links}</li>\n"
    end
    output += "\t\t</ol>\n\t</ul>"
    alphabet_index_links(used_letters, output)
  end

  def write_index_file
    dst = "#{@parentDir}/#{index_filename}"
    html = Nokogiri::HTML(html_document(@file_body)).to_html
    pretty_html = HtmlBeautifier.beautify(html)
    File.write(dst, pretty_html)
  end

  def main
    generate_html_list
    write_index_file
  end

  def html_document(contents)
    <<-HTML
      <!DOCTYPE html>
      <html lang="#{@language}">
        #{write_html_head}
      <body>
        <main class="full">
          <a style="position: fixed; bottom: 3rem; right: 3rem;"
            class="btn btn-primary btn-lg"
            href="#top">#{I18n.t('back_to_top')}</a>&nbsp;
          #{contents}
        </main>
      </body>
      </html>
    HTML
  end

  # TODO: The course info needs to be more visible somehwre.
  def write_html_head
    title_key = 'index'
    title_key = 'sparks_index' if @parentDir.include?('sparks')

    <<~HTML
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{I18n.t(title_key)}</title>
        <script type="text/javascript" src="/bjc-r/llab/loader.js"></script>
      </head>
    HTML
  end


  # TODO: Mimic ActiveSupport's inflector methods
  # Alteranatively, downcase by word, except for known exceptions
  def keep_Capitalized?(vocab)
    capitals = ['IP', 'DDoS', 'SSL', 'TLS', 'TCP', 'IA', 'IPA', 'PCT', 'PI', 'AI', 'ADT', 'API',
                'Creative Commons', 'ISPs', 'Commons', 'Creative', 'Boolean', 'Booleano']
    capitals.each do |item|
      # Can't quite be exact match bc of terms like "API (Application Programming Interface)"
      if vocab.match?(item)
        return true
      elsif vocab.match?(/\(.+\)/)
        return true
      end
    end
    false
  end

  def index_downcase(vocab)
    words = vocab.split(' ')
    words.map! do |word|
      if CAPITALS.include?(word)
        word
      else
        word.downcase
      end
    end
    words.join(' ')
  end
end
