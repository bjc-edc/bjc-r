# frozen_string_literal: true

require 'fileutils'
require 'nokogiri'

# HTMLCleaner pre-processes a BJC curriculum HTML page so pandoc can
# convert it cleanly to LaTeX.
#
# Responsibilities:
# - rewrite "/bjc-r/..." image src/href to absolute filesystem paths
# - rewrite "data-gifffer" (lazy-loaded animated GIFs) to plain src
# - drop unsupported nodes (scripts, audio, video, interactive snap embeds)
# - mark the custom BJC <div class="..."> callouts with fenced div syntax
#   pandoc understands via the native_divs/raw_html readers, so the LaTeX
#   converter wraps them in the matching `bjc<class>` environment.
# - extract the page <h2> title so the caller can use it as the section
#   heading and we don't end up with a redundant heading inside the body.
class HTMLCleaner
  # BJC <div class="..."> values that should map to LaTeX environments
  # defined in templates/preamble.tex.
  CALLOUT_CLASSES = {
    'learn'         => 'bjclearn',
    'takeNote'      => 'bjctakenote',
    'forYouToDo'    => 'bjcforyoutodo',
    'endnote'       => 'bjcendnote',
    'sidenote'      => 'bjcsidenote',
    'sidenoteBig'   => 'bjcsidenote',
    'vocab'         => 'bjcvocab',
    'definition'    => 'bjcvocab',
    'pseudop'       => 'bjcpseudop',
  }.freeze

  attr_reader :title

  # Characters that survive in a path passed through pandoc but trip
  # \includegraphics: anything pandoc would emit as an escape macro.
  UNSAFE_PATH_CHARS = /[\\'"&%#$~^\s{}<>?\[\]]/.freeze

  def initialize(html_path, bjc_root:, image_cache_dir: nil)
    @html_path = html_path
    @bjc_root = bjc_root
    @image_cache_dir = image_cache_dir
    @missing_images = []
  end

  def missing_images
    @missing_images.uniq
  end

  # Returns a cleaned HTML fragment (just the body innards) suitable for
  # piping into `pandoc -f html -t latex`.
  def clean
    raw = File.read(@html_path, encoding: 'BINARY').force_encoding('UTF-8')
    raw = raw.scrub('?')
    doc = Nokogiri::HTML5.parse(raw)

    body = doc.at_css('body') || doc

    extract_title(doc)
    strip_unsupported(body)
    rewrite_image_paths(body)
    rewrite_links(body)
    flatten_collapsible(body)
    inject_index_markers(body)
    wrap_callouts(body)

    body.inner_html
  end

  private

  def extract_title(doc)
    h2 = doc.at_css('body h2')
    @title = h2 ? h2.text.strip : (doc.at_css('title')&.text&.strip || '')
    # Remove the first H2 so we don't double-print the title in the body.
    h2&.remove
  end

  def strip_unsupported(body)
    body.css('script, audio, video, iframe, link, style, noscript').each(&:remove)
    body.css('a.run, a.report').each(&:remove)
    body.css('.collapse').each(&:remove)
    body.css('[data-toggle]').each { |n| n.delete('data-toggle') }
    # Strip empty paragraphs / divs left behind
    body.css('p,div,span').each do |n|
      n.remove if n.children.empty? && n.text.strip.empty?
    end
  end

  # Image formats pdflatex's \includegraphics can read.
  PDFLATEX_IMAGE_EXTS = %w[.png .jpg .jpeg .pdf .eps].freeze

  def rewrite_image_paths(body)
    body.css('img').each do |img|
      src = img['data-gifffer'] || img['src']
      next unless src
      img.delete('data-gifffer')

      local = resolve_local_path(src)
      ext = local ? File.extname(local).downcase : nil

      if local && File.exist?(local) && PDFLATEX_IMAGE_EXTS.include?(ext)
        img['src'] = sanitize_image_path(local)
      else
        # Either the file is missing, or it's a GIF/SVG/etc. pdflatex
        # can't embed directly. Replace with an italicized alt-text
        # placeholder so the surrounding prose still makes sense.
        @missing_images << src if !local || !File.exist?(local)
        placeholder = Nokogiri::XML::Node.new('em', body)
        alt = img['alt'].to_s.strip
        label = if !local || !File.exist?(local)
                  alt.empty? ? '[image missing]' : "[image: #{alt}]"
                else
                  alt.empty? ? "[#{ext.sub('.', '').upcase} image]" : "[#{ext.sub('.', '').upcase}: #{alt}]"
                end
        placeholder.content = label
        img.replace(placeholder)
      end
    end
  end

  # \includegraphics doesn't expand TeX macros in its filename argument,
  # so pandoc-emitted `\textquotesingle{}` etc. become literal lookups
  # that fail. Symlink any image whose path contains unsafe characters
  # to a sanitized name inside the image cache dir, and return that path.
  def sanitize_image_path(local_path)
    return local_path unless @image_cache_dir
    return local_path unless local_path =~ UNSAFE_PATH_CHARS

    FileUtils.mkdir_p(@image_cache_dir)
    safe_name = local_path
                .sub(/^\/+/, '')
                .gsub(UNSAFE_PATH_CHARS, '_')
                .gsub(/\/+/, '__')
    safe_path = File.join(@image_cache_dir, safe_name)
    unless File.exist?(safe_path) || File.symlink?(safe_path)
      File.symlink(local_path, safe_path)
    end
    safe_path
  end

  def rewrite_links(body)
    body.css('a[href]').each do |a|
      href = a['href']
      # Convert "/bjc-r/..." links to a https://bjc.edc.org/... style
      # so they are clickable in the PDF.
      if href.start_with?('/bjc-r/')
        a['href'] = "https://bjc.edc.org#{href}"
      elsif href.start_with?('#')
        # Strip same-page anchors (collapsibles, etc.) since the targets
        # were removed by strip_unsupported.
        a.replace(a.children)
      end
    end
  end

  # Walk the body and inject hex-encoded index sentinels next to each:
  # - vocab term (every <strong> inside a .vocab / .vocab.summaryBox box)
  # - On-the-AP-Exam reference (every comma-separated code inside a
  #   .exam* box's `.ap-standard` child)
  # - self-check question (the `identifier` text on each
  #   `.assessment-data` block)
  #
  # The sentinel format `XBJCIDX<v|x|s>__<hex>__XEND` survives pandoc
  # because it only uses ASCII letters + digits + underscores; the
  # LatexRenderer decodes the hex back to UTF-8 and emits the matching
  # \index{...} command.
  def inject_index_markers(body)
    # Vocab terms: top-level <strong> children of vocab boxes. Skip
    # ones that look like the lab/page reference (e.g. "Lab 2, Page 3"),
    # which sit inside a leading <a><b>...</b></a>.
    body.css('div.vocab, div.vocab.summaryBox').each do |box|
      box.css('strong').each do |strong|
        # Skip strongs that are inside the leading reference anchor.
        next if strong.ancestors.any? { |a| a.name == 'a' }
        term = strong.text.strip
        next if term.empty? || term.length > 60
        strong.add_previous_sibling(index_marker('v', term))
      end
    end

    # On-the-AP-Exam: pull AP-standard codes (comma separated) from the
    # `.ap-standard` div inside any .exam / .exam.summaryBox / .examFullWidth.
    body.css('div.exam, div.exam.summaryBox, div.examFullWidth').each do |box|
      box.css('div.ap-standard').each do |std|
        std.text.split(/[,;]/).map(&:strip).reject(&:empty?).each do |code|
          # Codes look like "AAP-3.A.6", "CRD-2.B.1", possibly with a
          # trailing "first sentence" annotation. Keep up to first space.
          code = code.split(/\s/).first
          next if code.nil? || code.empty? || code.length > 25
          std.add_previous_sibling(index_marker('x', code))
        end
      end
    end

    # Self-check questions: identifier attribute is the human question
    # text. Trim to 60 chars so the index entry fits on a line.
    body.css('div.assessment-data').each do |q|
      ident = q['identifier'].to_s.strip
      next if ident.empty?
      ident = ident[0, 60] + (ident.length > 60 ? '…' : '')
      q.add_previous_sibling(index_marker('s', ident))
    end
  end

  # Wrap an index term as a hex-encoded sentinel that pandoc passes
  # through untouched (ASCII letters + digits + underscores only).
  def index_marker(category, term)
    hex = term.unpack1('H*')
    "<span>XBJCIDX#{category}__#{hex}__XEND</span>"
  end

  def flatten_collapsible(body)
    # Some BJC pages wrap content in <div data-toggle="collapse"> +
    # <div class="collapse">. After strip_unsupported the targets are
    # gone; remove the toggle wrappers too.
    body.css('[data-toggle]').each { |n| n.replace(n.children) }
  end

  # Tag a recognized BJC callout div with text-marker sentinels so the
  # LatexRenderer can swap them for `\begin{env}/\end{env}` pairs after
  # pandoc has done its HTML → LaTeX conversion.
  #
  # We use plain-text markers (XBJCBEGIN... / XBJCEND...) rather than
  # HTML comments because pandoc drops HTML comments. The marker only
  # uses letters + digits so LaTeX won't escape any of its characters.
  def wrap_callouts(body)
    body.css('div[class]').each do |div|
      classes = div['class'].to_s.split(/\s+/)
      env = classes.map { |c| CALLOUT_CLASSES[c] }.compact.first
      next unless env

      tag = env.upcase.gsub(/[^A-Z0-9]/, '')
      # Wrap markers in their own paragraphs so pandoc emits them as
      # standalone text lines we can grep-replace.
      div.add_previous_sibling("<p>XBJCBEGIN#{tag}XEND</p>")
      div.add_next_sibling("<p>XBJCEND#{tag}XEND</p>")
      div.replace(div.children)
    end
  end

  def resolve_local_path(src)
    return nil if src.nil? || src.empty?
    # Already an absolute file path
    return src if src.start_with?('/workspace/') || (src.start_with?('/') && File.exist?(src) && !src.start_with?('/bjc-r/'))

    if src.start_with?('/bjc-r/')
      File.join(@bjc_root, src.sub(%r{^/bjc-r/}, ''))
    elsif src.start_with?('http://', 'https://')
      nil # remote image — skip for offline build
    else
      # relative path — resolve against the HTML page's directory
      File.expand_path(src, File.dirname(@html_path))
    end
  end
end
