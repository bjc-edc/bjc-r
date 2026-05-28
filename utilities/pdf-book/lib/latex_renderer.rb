# frozen_string_literal: true

require 'open3'
require 'shellwords'

require_relative 'html_cleaner'

# LatexRenderer takes a cleaned BJC HTML fragment and produces a LaTeX
# fragment via pandoc, post-processed to:
# - rewrite our sentinel BJC_ENV_BEGIN/END comments into the matching
#   \begin{env}/\end{env} pairs (preamble defines bjclearn etc.)
# - shift pandoc's default heading level by +2 so the page's intrinsic
#   H2/H3/H4 become \subsubsection / \paragraph and don't collide with
#   the chapter/section/subsection scaffolding we apply outside.
# - escape stray Snap! lightning glyphs that have no font coverage.
class LatexRenderer
  PANDOC = ENV['PANDOC'] || 'pandoc'

  def initialize(bjc_root:, image_cache_dir: nil)
    @bjc_root = bjc_root
    @image_cache_dir = image_cache_dir
  end

  # Convert a single HTML page into a LaTeX fragment.
  # Returns [latex_string, html_cleaner] so the caller can inspect
  # extracted title and missing-image warnings.
  def render_page(html_path)
    cleaner = HTMLCleaner.new(html_path, bjc_root: @bjc_root,
                              image_cache_dir: @image_cache_dir)
    cleaned_html = cleaner.clean

    latex = pandoc_html_to_latex(cleaned_html)
    latex = post_process(latex)

    [latex, cleaner]
  end

  private

  def pandoc_html_to_latex(html)
    cmd = [
      PANDOC,
      '-f', 'html+raw_html',
      '-t', 'latex',
      '--shift-heading-level-by=2',
      '--wrap=preserve',
    ]
    stdout, stderr, status = Open3.capture3(*cmd, stdin_data: html)
    unless status.success?
      warn "pandoc failed: #{stderr}"
      return "% pandoc failed: #{stderr.lines.first}\n"
    end
    stdout
  end

  # Index categories — must match the single-letter codes HTMLCleaner
  # writes in inject_index_markers.
  INDEX_CATEGORIES = {
    'v' => 'Vocabulary',
    'x' => 'On the AP Exam',
    's' => 'Self-Check Questions',
  }.freeze

  def post_process(latex)
    # Rewrite XBJCBEGINtagXEND / XBJCENDtagXEND sentinels (emitted by
    # HTMLCleaner) into matching \begin{env}/\end{env} pairs. The
    # sentinel uses only letters + digits so pandoc/LaTeX don't escape
    # any characters and the regex matches the surviving form.
    latex = latex.gsub(/XBJCBEGIN([A-Z0-9]+)XEND/) { "\\begin{#{$1.downcase}}" }
    latex = latex.gsub(/XBJCEND([A-Z0-9]+)XEND/)   { "\\end{#{$1.downcase}}" }
    # Decode XBJCIDX<v|x|s>__<hex>__XEND markers (from
    # HTMLCleaner#inject_index_markers) into \index{Category!Term}.
    # pandoc escapes underscores to `\_`, so the regex allows either
    # form for the separators.
    latex = latex.gsub(/XBJCIDX([vxs])(?:\\?_){2}([0-9a-f]+)(?:\\?_){2}XEND/) do
      cat = INDEX_CATEGORIES[$1] || 'Index'
      term = [$2].pack('H*').force_encoding('UTF-8')
      "\\index{#{escape_index_term(cat)}!#{escape_index_term(term)}}"
    end
    # Strip unicode lightning + a handful of glyphs LaTeX (Latin Modern)
    # can't render, replacing with text equivalents.
    latex = latex.gsub("⚡", '\\snaplightning{}')
    latex
  end

  # Escape a string for use as an \index{} argument. There are two
  # escaping layers to consider:
  # - makeindex meta-characters (`!` level, `@` sort, `|` format, `"`
  #   escape) need a leading `"`.
  # - LaTeX-special characters (`_ # & $ % ^ ~`) need their usual
  #   backslash escapes because the index entry is rendered by LaTeX
  #   when the .ind file is read back. (`\`, `{`, `}` we drop, since
  #   they're rare in BJC vocab/AP-code/question text and risky to
  #   round-trip through makeindex.)
  def escape_index_term(s)
    s.to_s
     .gsub(/[{}\\]/, '')           # drop TeX grouping/backslash
     .gsub('"', '""')               # makeindex escape
     .gsub('!', '"!')
     .gsub('@', '"@')
     .gsub('|', '"|')
     .gsub('_', '\\_')              # LaTeX specials
     .gsub('#', '\\#')
     .gsub('&', '\\&')
     .gsub('$', '\\$')
     .gsub('%', '\\%')
     .gsub('^', '\\textasciicircum{}')
     .gsub('~', '\\textasciitilde{}')
     .strip
  end
end
