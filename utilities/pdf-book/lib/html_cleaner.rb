# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'i18n'
require 'nokogiri'
require 'open3'

# Make sure the shared bjc_translations.yml from utilities/build-tools/
# is loaded exactly once across this process. The pdf-book pipeline
# uses the same translation source as the existing rebuild scripts so
# strings stay in sync.
unless I18n.backend.send(:translations).key?(:en)
  I18n.load_path += Dir[File.expand_path('../../build-tools/*.yml', __dir__)]
  I18n.backend.load_translations
end

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
    'learn'             => 'bjclearn',
    'takeNote'          => 'bjctakenote',
    'forYouToDo'        => 'bjcforyoutodo',
    'endnote'           => 'bjcendnote',
    'sidenote'          => 'bjcsidenote',
    'sidenoteBig'       => 'bjcsidenote',
    'vocab'             => 'bjcvocab',
    'vocabBig'          => 'bjcvocab',
    'vocabFullWidth'    => 'bjcvocab',
    'vocabSummary'      => 'bjcvocab',
    'definition'        => 'bjcvocab',
    'exam'              => 'bjcexam',
    'examBig'           => 'bjcexam',
    'examFullWidth'     => 'bjcexam',
    'examSummary'       => 'bjcexam',
    'atwork'            => 'bjcatwork',
    'atworkFullWidth'   => 'bjcatwork',
    'dialogue'          => 'bjcdialogue',
    'ifTime'            => 'bjciftime',
    'takeItFurther'     => 'bjctakefurther',
    'takeItTeased'      => 'bjctakefurther',
    'takeItTeaser'      => 'bjctakefurther',
    'time'              => 'bjctime',
    'narrower'          => 'bjcnarrower',
    'narrowblue'        => 'bjcnarrowblue',
    'narrowpurple'      => 'bjcnarrowpurple',
    'sideHOM'           => 'bjcsidenote',
    'sideHOMbig'        => 'bjcsidenote',
    'pseudop'           => 'bjcpseudop',
  }.freeze

  # Maps a BJC HTML class to the I18n key whose value is the heading
  # text that the production CSS / llab JS injects at runtime (mirrors
  # `:before` content rules in bjc.css plus `llab.TRANSLATIONS` in
  # library.js). The actual strings live in
  # utilities/build-tools/bjc_translations.yml so all of llab and the
  # build tools share one source of truth.
  HEADING_I18N_KEYS = {
    'vocab'           => :vocab,
    'vocabBig'        => :vocab,
    'vocabFullWidth'  => :vocab,
    'vocabSummary'    => :vocab,
    'exam'            => :exam,
    'examBig'         => :exam,
    'examFullWidth'   => :exam,
    'examSummary'     => :exam,
    'atwork'          => :'callout.atwork',
    'atworkFullWidth' => :'callout.atwork',
    'dialogue'        => :'callout.dialogue',
    'ifTime'          => :'callout.if_time',
    'takeItFurther'   => :'callout.take_it_further',
    'takeItTeased'    => :'callout.take_it_further',
    'takeItTeaser'    => :'callout.take_it_further',
    'time'            => :'callout.short_on_time',
  }.freeze

  attr_reader :title

  # Characters that survive in a path passed through pandoc but trip
  # \includegraphics: anything pandoc would emit as an escape macro.
  UNSAFE_PATH_CHARS = /[\\'"&%#$~^\s{}<>?\[\]]/.freeze

  def initialize(html_path, bjc_root:, language: 'en',
                 image_cache_dir: nil, qr_dir: nil)
    @html_path = html_path
    @bjc_root = bjc_root
    @language = language
    @image_cache_dir = image_cache_dir
    @qr_dir = qr_dir
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
    expand_collapsibles(body)
    # Inject raw-LaTeX sentinels (KaTeX, Snap! brand mark) BEFORE the
    # link/image rewrites, because rewrite_run_links replaces the inner
    # text of <a class="run">…</a> and would otherwise nuke any
    # <span class="snap"> nested inside it.
    inject_raw_latex_markers(body)
    rewrite_image_paths(body)
    rewrite_run_links(body)
    rewrite_links(body)
    flatten_collapsible(body)
    inject_index_markers(body)
    strip_hidden_classes(body)
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
    body.css('a.report').each(&:remove)
    body.css('[data-toggle], [data-bs-toggle]').each do |n|
      n.delete('data-toggle')
      n.delete('data-bs-toggle')
    end
    # Strip empty paragraphs / divs left behind.
    body.css('p,div,span').each do |n|
      n.remove if n.children.empty? && n.text.strip.empty?
    end
  end

  # In a static PDF "click to expand" makes no sense. For the BJC
  # collapsible patterns we see (Bootstrap `.collapse` + an `<a
  # data-toggle="collapse">` trigger, and native `<details>/<summary>`),
  # convert the trigger into a bold lead-in line and unwrap the body so
  # the content always shows.
  def expand_collapsibles(body)
    # Native <details>: flatten — <summary> becomes a bold paragraph,
    # the rest of the content stays in place.
    body.css('details').each do |det|
      summary = det.at_css('summary')
      if summary
        bold = Nokogiri::XML::Node.new('p', body)
        strong = Nokogiri::XML::Node.new('strong', body)
        strong.content = summary.text.strip
        bold.add_child(strong)
        summary.replace(bold)
      end
      det.replace(det.children)
    end

    # Bootstrap "data-toggle" / "data-bs-toggle" triggers (BS4 and BS5
    # respectively): keep the trigger text as a bold lead-in, but drop
    # the link semantics so it isn't rendered as a dead URL in the PDF.
    body.css('a[data-toggle], a[data-target], a[data-bs-toggle], a[data-bs-target]').each do |a|
      bold = Nokogiri::XML::Node.new('strong', body)
      bold.content = a.text.strip
      a.replace(bold)
    end
  end

  # Remove the now-stale toggle attributes from any element that
  # wasn't replaced above (e.g. a <button>).
  def flatten_collapsible(body)
    body.css('[data-toggle], [data-bs-toggle]').each do |n|
      n.delete('data-toggle')
      n.delete('data-bs-toggle')
      n.delete('data-target')
      n.delete('data-bs-target')
    end
  end

  # Image formats lualatex's \includegraphics can read.
  PDFLATEX_IMAGE_EXTS = %w[.png .jpg .jpeg .pdf .eps].freeze

  def rewrite_image_paths(body)
    body.css('img').each do |img|
      src = img['data-gifffer'] || img['src']
      next unless src
      img.delete('data-gifffer')

      local = resolve_local_path(src)
      ext = local ? File.extname(local).downcase : nil

      # SVGs: convert to PDF on the fly so includegraphics can embed
      # them losslessly. Cached under image_cache_dir as <name>.pdf.
      if local && File.exist?(local) && ext == '.svg'
        converted = convert_svg_to_pdf(local)
        if converted
          img['src'] = sanitize_image_path(converted)
          next
        end
      end

      # GIFs: extract the first frame as a PNG so the reader still
      # sees the image, and wrap the <img> in a link to the original
      # animated GIF on the live site so they can scan/click through
      # to view the animation.
      if local && File.exist?(local) && ext == '.gif'
        frame = extract_gif_first_frame(local)
        if frame
          img['src'] = sanitize_image_path(frame)
          link_url = src.start_with?('/') ? "#{BJC_HOST}#{src}" : src
          link = Nokogiri::XML::Node.new('a', body)
          link['href'] = link_url
          parent_of_img = img.parent
          img.replace(link)
          link.add_child(img)
          next
        end
      end

      if local && File.exist?(local) && PDFLATEX_IMAGE_EXTS.include?(ext)
        img['src'] = sanitize_image_path(local)
      else
        # Either the file is missing, or it's a format lualatex can't
        # embed and we have no converter for. Replace with an italicized
        # alt-text placeholder so the surrounding prose still makes sense.
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

  # Extract frame 0 of an animated GIF as PNG, cached under
  # image_cache_dir. Returns the cached PNG path, or nil if ffmpeg
  # isn't installed or the conversion fails.
  def extract_gif_first_frame(gif_path)
    return nil unless @image_cache_dir
    FileUtils.mkdir_p(@image_cache_dir)
    cache_name = 'gif_' + Digest::SHA1.hexdigest(gif_path)[0, 16] + '.png'
    cache_path = File.join(@image_cache_dir, cache_name)

    if File.exist?(cache_path) && File.mtime(cache_path) >= File.mtime(gif_path)
      return cache_path
    end

    # -vframes 1 grabs the first frame; -y overwrites; -loglevel error
    # suppresses ffmpeg's progress chatter.
    cmd = ['ffmpeg', '-y', '-loglevel', 'error',
           '-i', gif_path, '-vframes', '1', cache_path]
    out, status = Open3.capture2e(*cmd)
    return cache_path if status.success? && File.exist?(cache_path)

    warn "  ffmpeg failed for #{gif_path}: #{out.lines.first&.chomp}"
    nil
  rescue Errno::ENOENT
    warn '  ffmpeg not installed; GIFs will render as placeholders'
    nil
  end

  # rsvg-convert (librsvg2-bin) ships a clean SVG -> PDF path. We
  # cache the converted file by source mtime so repeated runs are
  # cheap. Returns the cached PDF path, or nil if conversion fails /
  # the tool is missing.
  def convert_svg_to_pdf(svg_path)
    return nil unless @image_cache_dir
    FileUtils.mkdir_p(@image_cache_dir)
    cache_name = 'svg_' + Digest::SHA1.hexdigest(svg_path)[0, 16] + '.pdf'
    cache_path = File.join(@image_cache_dir, cache_name)

    if File.exist?(cache_path) && File.mtime(cache_path) >= File.mtime(svg_path)
      return cache_path
    end

    out, status = Open3.capture2e('rsvg-convert', '-f', 'pdf', '-o', cache_path, svg_path)
    return cache_path if status.success? && File.exist?(cache_path)

    warn "  rsvg-convert failed for #{svg_path}: #{out.lines.first&.chomp}"
    nil
  rescue Errno::ENOENT
    warn '  rsvg-convert not installed; SVG images will render as placeholders'
    nil
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

  # Look up the heading text for a callout class via I18n. Returns nil
  # if the class isn't headed (the JS / CSS leaves it as a styled
  # marker only) or the lookup misses for this language.
  def lookup_callout_heading(klass)
    key = HEADING_I18N_KEYS[klass]
    return nil unless key
    I18n.t(key, locale: @language.to_sym, default: nil) ||
      I18n.t(key, locale: :en, default: nil)
  end

  # Wrap an index term as a hex-encoded sentinel that pandoc passes
  # through untouched (ASCII letters + digits + underscores only).
  def index_marker(category, term)
    hex = term.unpack1('H*')
    "<span>XBJCIDX#{category}__#{hex}__XEND</span>"
  end

  # Inject sentinels for content that should round-trip as RAW LaTeX
  # through pandoc:
  #   - .katex / .katex-inline / .katex-block — wrap text content as
  #     $...$ (inline) or \[...\] (block).
  #   - <span class="snap"> — replace with \snap{} (renders "Snap\!" in
  #     italic per the snap-manual style).
  #
  # Uses the same hex-encoded sentinel format as inject_index_markers,
  # decoded back to raw LaTeX in LatexRenderer.
  def inject_raw_latex_markers(body)
    body.css('.katex, .katex-inline, .katex-block, span.katex').each do |k|
      tex = k.text.strip
      next if tex.empty?
      is_block = k['class'].to_s.split(/\s+/).include?('katex-block') ||
                 k.parent&.name == 'div'
      cat = is_block ? 'M' : 'm'
      hex = tex.unpack1('H*')
      replacement = Nokogiri::XML::Node.new('span', body)
      replacement.content = "XBJCTEX#{cat}__#{hex}__XEND"
      k.replace(replacement)
    end

    body.css('span.snap, .snap').each do |s|
      # The text content is typically "snap" — we ignore it and emit
      # the brand mark macro instead.
      replacement = Nokogiri::XML::Node.new('span', body)
      replacement.content = 'XBJCSNAPMARKXEND'
      s.replace(replacement)
    end
  end

  # Snap! "run" links open the linked .xml project inside Snap! in a
  # new tab. In the PDF the link target should resolve to the live
  # snap.berkeley.edu URL (clickable in the reader) and, when QRDirSet,
  # we also embed a tiny QR code so paper readers can scan to load.
  SNAP_RUN_BASE = 'https://snap.berkeley.edu/snap/snap.html#open:'
  BJC_HOST = 'https://bjc.edc.org'

  def rewrite_run_links(body)
    body.css('a.run, a.js-run').each do |a|
      href = a['href'].to_s
      next if href.empty?

      target = href.start_with?('/') ? "#{BJC_HOST}#{href}" : href
      run_url = "#{SNAP_RUN_BASE}#{target}"

      # If the <a> has no visible text (just contains an icon image),
      # provide a tiny lead-in so the link is anchorable in the PDF.
      label = a.text.strip
      label = '(load in Snap!)' if label.empty?

      # Replace the <a> with the same link pointing at run_url, plus an
      # optional QR-code sentinel that LatexRenderer expands.
      a['href'] = run_url
      a.attributes.each { |name, _| a.remove_attribute(name) unless name == 'href' }
      # Strip the inner image so we don't end up with the [PNG: load]
      # placeholder mixed with the link text.
      a.css('img').each(&:remove)
      a.content = label

      if @qr_dir
        hex = run_url.unpack1('H*')
        marker = Nokogiri::XML::Node.new('span', body)
        marker.content = " XBJCQR__#{hex}__XEND"
        a.add_next_sibling(marker)
      end
    end
  end

  # Classes that the production CSS hides (`display: none`) — author
  # notes, draft TODOs, and AP/CSTA standard codes that act as labels
  # in the web UI but shouldn't appear in the printed book. Run this
  # AFTER inject_index_markers so the .ap-standard codes still get
  # extracted into the "On the AP Exam" index entries before being
  # removed from the body.
  HIDDEN_CLASSES = %w[
    todo
    comment
    commentBig
    ap-standard
    csta-standard
  ].freeze

  def strip_hidden_classes(body)
    HIDDEN_CLASSES.each do |klass|
      body.css("div.#{klass}, span.#{klass}, p.#{klass}").each(&:remove)
    end
  end

  # Tag a recognized BJC callout div with text-marker sentinels so the
  # LatexRenderer can swap them for `\begin{env}/\end{env}` pairs after
  # pandoc has done its HTML → LaTeX conversion.
  #
  # We use plain-text markers (XBJCBEGIN... / XBJCEND...) rather than
  # HTML comments because pandoc drops HTML comments. The marker only
  # uses letters + digits so LaTeX won't escape any of its characters.
  #
  # If the class also has a CSS-injected heading (Vocabulary, On the AP
  # Exam, Take It Further, etc.) we prepend the heading text inside the
  # callout so the printed book matches the rendered web layout.
  def wrap_callouts(body)
    body.css('div[class]').each do |div|
      classes = div['class'].to_s.split(/\s+/)
      env = classes.map { |c| CALLOUT_CLASSES[c] }.compact.first
      next unless env

      tag = env.upcase.gsub(/[^A-Z0-9]/, '')
      heading = classes.map { |c| lookup_callout_heading(c) }.compact.first

      div.add_previous_sibling("<p>XBJCBEGIN#{tag}XEND</p>")
      if heading
        # `.vocab.summaryBox` deliberately suppresses the "Vocabulary"
        # heading because each entry already starts with the lab/page
        # reference — mirror that behavior here.
        suppressed = (classes.include?('summaryBox') && (env == 'bjcvocab' || env == 'bjcexam'))
        unless suppressed
          div.add_previous_sibling(
            "<p><strong>#{Nokogiri::XML::Text.new(heading, body).to_xml}</strong></p>"
          )
        end
      end
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
