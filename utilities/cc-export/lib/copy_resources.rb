# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'set'

module CCExport
  # Copies HTML pages and their referenced assets into the cartridge for
  # "copy" mode, rewriting absolute /bjc-r/... paths so the bundle is portable
  # outside the bjc-r origin.
  #
  # Same scope as the live site convention: we follow img/script/link/anchor
  # references (`src`, `href`, `data-src`), and pull asset files (images, css,
  # js, fonts, media). Cross-page HTML anchors get path-rewritten but are not
  # transitively crawled — the topic file already drives which pages we copy.
  class CopyResources
    ASSET_EXTS = %w[
      .png .jpg .jpeg .gif .svg .webp .ico
      .css .js
      .mp3 .mp4 .webm .ogg
      .pdf .woff .woff2 .ttf .eot
    ].to_set.freeze

    ASSET_ATTR_RE = /(\b(?:src|href|data-src)\s*=\s*)(["'])(\/bjc-r\/[^"']+)(["'])/i

    BJC_PREFIX = '/bjc-r/'

    attr_reader :web_subdir

    def initialize(bjc_root, staging_dir, web_subdir: 'web_resources')
      @bjc_root = Pathname.new(bjc_root)
      @staging_dir = Pathname.new(staging_dir)
      @web_subdir = web_subdir
      @copied = Set.new
    end

    # Copy a page given its /bjc-r/-relative path and return
    # [primary_href, extra_hrefs] both relative to the cartridge root.
    def copy_page(page_relpath)
      rel = strip_prefix(page_relpath)
      src = @bjc_root.join(rel)
      raise Errno::ENOENT, src.to_s unless src.file?

      cartridge_rel = File.join(@web_subdir, rel)
      dest = @staging_dir.join(cartridge_rel)
      FileUtils.mkdir_p(dest.dirname)

      text = src.read(mode: 'r:UTF-8', invalid: :replace, undef: :replace)
      depth = rel.count('/')
      back = '../' * depth  # back to the @web_subdir root
      rewritten, asset_paths = rewrite_html(text, back)
      dest.write(rewritten)
      @copied << src.to_s

      extras = asset_paths.filter_map { |abs| copy_asset(abs) }.uniq
      [cartridge_rel, extras]
    end

    private

    def strip_prefix(path)
      path = path.dup
      path = path.sub(/\A\/bjc-r\//, '')
      path
    end

    def rewrite_html(text, back)
      assets = []
      rewritten = text.gsub(ASSET_ATTR_RE) do
        attr = Regexp.last_match(1)
        q1   = Regexp.last_match(2)
        abs  = Regexp.last_match(3)
        q2   = Regexp.last_match(4)
        assets << abs
        "#{attr}#{q1}#{back}#{abs.sub(/\A#{BJC_PREFIX}/, '')}#{q2}"
      end
      [rewritten, assets]
    end

    def copy_asset(abs_path)
      return nil unless abs_path.start_with?(BJC_PREFIX)

      rel = abs_path.sub(/\A#{BJC_PREFIX}/, '').split('?', 2).first.split('#', 2).first
      return nil if rel.nil? || rel.empty?
      return nil unless ASSET_EXTS.include?(File.extname(rel).downcase)

      src = @bjc_root.join(rel)
      return nil unless src.file?

      cartridge_rel = File.join(@web_subdir, rel)
      return cartridge_rel if @copied.include?(src.to_s)

      dest = @staging_dir.join(cartridge_rel)
      FileUtils.mkdir_p(dest.dirname)
      FileUtils.copy_file(src, dest)
      @copied << src.to_s
      cartridge_rel
    end
  end
end
