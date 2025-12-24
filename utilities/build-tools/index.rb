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
# These are also not split when they appear in phrases
# Contains both English and Spanish terms.
CAPS_SPECIALS = [
  'Creative Commons',
  'IP', 'DDoS', 'SSL', 'TLS', 'TCP', 'AI', 'ADT', 'API',
  'ISPs', 'Boolean',
  # CSP Spanish
  'IA', 'IPA', 'PCT', 'PI', 'Booleano',
  # Sparks
  'SPOF'
].freeze

class Index
  attr_accessor :language, :vocab_url_map, :file_body, :terms_list

  def initialize(path, language = 'en')
    @parentDir = path
    @language = language
  end

  def sparks?
    @parentDir.include?('sparks/')
  end

  def language_ext
    @language_ext ||= @language == 'en' ? '' : ".#{@language}"
  end

  def index_filename
    "#{FILE_NAME}#{language_ext}.html"
  end

  def locale_alphabet
    return ('a'..'z').to_a if @language == 'en'

    %w[a b c d e f g h i j k l m n ñ o p q r s t u v w x y z]
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

  # Localize using TwitterCldr and sort
  # These terms must match the keys in @vocab_url_map
  def sorted_vocab_list
    TwitterCldr::Collation::Collator.new(@language)
    terms_list.localize(@language).sort.to_a.map { |word| word.strip.gsub(': ', '') }
  end

  def filter_missing_mappings(vocab_list)
    vocab_list.select do |term|
      unless @vocab_url_map.key?(term)
        puts "Warning: No URL mapping found for vocab word: #{term}"
        false
      end
      true
    end
  end

  def vocab_by_letter
    # Remove diacritics for indexing if not in locale alphabet
    # Applies to "Índice",
    # but we don't have any ñ words yet that would need to be indexed under ñ.
    @vocab_by_letter ||= filter_missing_mappings(sorted_vocab_list).group_by do |word|
      I18n.transliterate(word[0]).downcase
    end
  end

  def li_term(word)
    links = @vocab_url_map[word].join(', ')
    "    <li>#{index_downcase(word)} &nbsp; #{links}</li>"
  end

  def li_terms(words)
    <<-HTML
      <ol style="list-style-type: square">
        #{words.map { |word| li_term(word) }.join("\n\t")}
      </ol>
    HTML
  end

  def all_letter_lists
    vocab_by_letter.map do |entry_letter, words|
      <<-HTML
        <li class="index-letter-target" style="list-style-type: none">
          <h2 id="#{entry_letter.upcase}">#{entry_letter.upcase}</h2>
          #{li_terms(words)}
        </li>
      HTML
    end.join("\n\t")
  end

  def generate_html_list
    <<-HTML
      <div class="index-letter-link">
        #{alphabet_links(vocab_by_letter.keys)}
      </div>
      <div>
        <ol style="list-style-type:square">
          #{all_letter_lists}
        </ol>
      </div>
    HTML
  end

  def write_index_file(contents)
    dst = "#{@parentDir}/#{index_filename}"
    html = Nokogiri::HTML(html_document(contents)).to_html
    pretty_html = HtmlBeautifier.beautify(html)
    File.write(dst, pretty_html)
  end

  def main
    write_index_file(generate_html_list)
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

  def write_html_head
    title_key = sparks? ? 'sparks_index' : 'index'
    <<~HTML
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{I18n.t(title_key)}</title>
        <script type="text/javascript" src="/bjc-r/llab/loader.js"></script>
      </head>
    HTML
  end

  def index_downcase(vocab)
    words = vocab.split(' ')
    words.map! do |word|
      # Remove () and : for matching
      cleaned_word = word.gsub(/[():]/, '')
      if CAPS_SPECIALS.include?(cleaned_word)
        word
      else
        word.downcase
      end
    end
    words.join(' ')
  end
end
