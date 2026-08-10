#!/usr/bin/env ruby
# frozen_string_literal: true

# Audit the link graph of the bjc-r repository.
#
# Builds a reference graph over every parseable file in the repo (HTML, .topic,
# CSS, JS), then answers three questions:
#
#   1. Which links are broken?  (internal targets that do not exist, plus
#      optionally external URLs that do not respond)
#   2. Which files are not linked from anywhere?
#   3. Which files are linked, but not reachable from a course or teacher guide?
#
# Reachability is measured from the six real entry points of the site:
#
#     index.html
#     course/bjc4nyc.html          course/bjc4nyc.es.html
#     course/sparks.html
#     course/bjc4nyc_teacher.html  course/sparks-teacher.html
#
# Parsing reuses the existing build tools rather than reimplementing them:
# BJCTopic parses .topic files (so comment stripping, raw-html blocks and the
# loose keyword matching behave exactly as they do in the real build), BJCCourse
# reads course pages, and Nokogiri parses HTML.
#
# Run it from the repository root, like the other build tools:
#
#   bundle exec ruby utilities/build-tools/link-audit.rb
#   bundle exec ruby utilities/build-tools/link-audit.rb --out /tmp/audit
#   bundle exec ruby utilities/build-tools/link-audit.rb --external
#   bundle exec ruby utilities/build-tools/link-audit.rb --check-anchors
#   bundle exec ruby utilities/build-tools/link-audit.rb --include-old
#   bundle exec ruby utilities/build-tools/link-audit.rb --include-all

require 'csv'
require 'fileutils'
require 'net/http'
require 'nokogiri'
require 'optparse'
require 'uri'

require_relative 'bjc_helpers'
require_relative 'course'
require_relative 'topic'

module LinkAudit
  # For language_ext, so course filenames are spelled the same way the
  # generators spell them.
  extend BJCHelpers

  # This file lives at <checkout>/utilities/build-tools/, so the checkout is two
  # folders up -- the same derivation rebuild-all.rb uses, and for the same
  # reason: cutting a path at the first "/bjc-r/" lands in the wrong place when
  # the checkout sits inside another folder of that name, as it does on CI.
  REPO_ROOT = File.realpath(File.expand_path('../..', __dir__))

  # The site is served from /bjc-r/, so an href of "/bjc-r/cur/x.html" is the
  # repo-relative path "cur/x.html". Same constant the generators use to turn
  # paths into URLs; llab.rootURL in llab/loader.js is the other half.
  WEB_ROOT = "#{BJCHelpers::SITE_ROOT}/".freeze

  # The six entry points of the site, as (course, language) pairs that BJCCourse
  # understands, plus the standalone landing page. Everything reachable from
  # here is "part of a course"; everything else is not.
  COURSES = [
    { course: 'bjc4nyc', language: 'en' },
    { course: 'bjc4nyc', language: 'es' },
    { course: 'sparks', language: 'en' },
    { course: 'bjc4nyc_teacher', language: 'en' },
    { course: 'sparks-teacher', language: 'en' }
  ].freeze

  LANDING_PAGE = 'index.html'

  def self.course_page(entry)
    "course/#{entry[:course]}#{language_ext(entry[:language])}.html"
  end

  ENTRY_POINTS = ([LANDING_PAGE] + COURSES.map { |entry| course_page(entry) }).freeze

  # Ignored everywhere: not crawled, not reported, and links into them are not
  # reported as broken.
  IGNORED = [
    %r{\Adocs/},
    %r{\Acur/blown-to-bits\.html\z}
  ].freeze

  # A path segment that is the word "old" -- `old/`, `old-labs/`, `very old/`,
  # `semi-old/`, `4-internet-old.topic`. These are known-dead archives, so they
  # are still crawled (to keep reference counts honest) but never reported as
  # problems. `golden/` and `bold/` deliberately do not match.
  OLD_SEGMENT = /(\A|[^a-z])old([^a-z]|\z)/i

  # Build tooling, tests, CI config and design sources. Part of the repo, but
  # never meant to be reachable from a course page.
  NON_WEB = [
    %r{\A\.github/}, /\A\.gitignore\z/, /\A\.htaccess\z/, /\A\.nojekyll\z/,
    /\A\.rspec\z/, /\A\.rubocop\.yml\z/, /\A\.tool-versions\z/,
    /\AGemfile(\.lock)?\z/, /\ACONTRIBUTING\.md\z/, /\AREADME\.md\z/,
    /\Arobots\.txt\z/, /\Afavicon\.ico\z/,
    %r{\Autilities/build-tools/}, %r{\Autilities/specs/}, %r{\Autilities/archive/},
    %r{\Autilities/images/}, %r{\Autilities/summaries/.*\.sh\z},
    %r{\Autilities/[^/]+\.(rb|py|sh|lua|docx|txt|md)\z},
    /\.(psd|ai|indd|blank)\z/,
    %r{\Allab/(docs|build)/}, %r{\Allab/README\.md\z},
    %r{\Aprog/python/.*\.py\z}
  ].freeze

  # Attributes that genuinely cause a fetch. `origsrc` (dead 2011 Moodle import
  # metadata) and `title` are deliberately excluded.
  LINK_ATTRS = %w[href src data-gifffer w3-include-html].freeze

  # Near-miss typos of a real link attribute: reported, not crawled.
  TYPO_ATTRS = { 'scr' => 'src', 'hef' => 'href', 'sr' => 'src' }.freeze

  PARSEABLE = /\.(html?|topic|css|js)\z/i

  # Minified/vendored code and the documented example config: scanning these for
  # path literals is all false positives.
  SKIP_JS = [%r{\Allab/lib/}, /\.min\.js\z/, %r{\Allab/(build|docs)/}].freeze

  WEB_EXT = 'html|htm|topic|xml|ypr|png|jpe?g|gif|svg|pdf|css|js|txt|json|zip|' \
            'sb|sb2|sb3|pptx|ppt|docx?|py|mov|mp4|webm|bmp|ico|php'
  KNOWN_EXT = /\.(#{WEB_EXT})\z/i
  JS_PATH = /["'`]([^"'`\s<>()]*\.(?:#{WEB_EXT})(?:[?\#&][^"'`\s<>]*)?)["'`]/i
  INLINE_ATTR = /(?:src|href)\s*=\s*\\?["']([^"'\\>]+)/i
  CSS_URL = /url\(\s*['"]?(.+?)['"]?\s*\)/i
  META_REFRESH = /url\s*=\s*["']?([^"';]+)/i
  BARE_EXTERNAL = /\A[\w-]+(\.[\w-]+)+\z/
  NON_FETCH = /\A(mailto|javascript|data|tel|about|file):/i

  # Curriculum pages are hand-written with no build step, so the anchors that
  # generated summary pages link back to are assigned in the browser and never
  # appear in the saved HTML. Counting the boxes the same way the browser does
  # is the only way to tell a real anchor from a dangling one.
  # Selectors mirror CONTENT_ANCHORS in llab/script/curriculum.js and the
  # `div.assessment-data` questions numbered by llab/script/quiz/multiplechoice.js.
  # IDs are `"#{type}-#{number}"` -- llab.anchorID and BJCHelpers#anchor_id.
  RUNTIME_ANCHORS = {
    'vocab' => 'div[class*="vocab"]',
    'exam' => 'div[class*="examFullWidth"]',
    'self-check' => 'div.assessment-data'
  }.freeze

  Ref = Struct.new(:source, :line, :raw, :kind, :target, :status, :detail,
                   keyword_init: true)

  def self.ignored?(path)
    IGNORED.any? { |re| re.match?(path) }
  end

  def self.old_path?(path)
    path.split('/').any? { |segment| OLD_SEGMENT.match?(segment) }
  end

  def self.non_web?(path)
    NON_WEB.any? { |re| re.match?(path) }
  end

  # ------------------------------------------------------------------
  # What exists on disk
  # ------------------------------------------------------------------
  class Inventory
    attr_reader :files, :symlinks, :lower

    def initialize(root)
      @root = root
      @files = Set.new
      @symlinks = Set.new
      tracked.each do |rel|
        if File.symlink?(File.join(@root, rel))
          @symlinks << rel
        else
          @files << rel
        end
      end
      # Links that differ only by case work on macOS but 404 on the Linux server.
      @lower = {}
      @files.each { |rel| @lower[rel.downcase] ||= rel }
      @exists_cache = {}
    end

    def tracked
      # -z, because plenty of paths contain spaces or non-ASCII characters that
      # git would otherwise C-quote and mangle.
      out = IO.popen(['git', '-C', @root, 'ls-files', '-z'], &:read)
      out.split("\0").reject(&:empty?)
    end

    # Resolve a repo-relative path through symlinks, back to a repo path, so
    # that `middle-school/x` and `sparks/x` collapse to one graph node.
    def canonical(rel)
      abs = File.expand_path(File.join(@root, rel))
      missing = []
      probe = abs
      while !File.exist?(probe) && probe != @root && probe != '/'
        missing.unshift(File.basename(probe))
        probe = File.dirname(probe)
      end
      real = File.exist?(probe) ? File.realpath(probe) : probe
      real = File.join(real, *missing) unless missing.empty?
      return nil unless real == @root || real.start_with?("#{@root}/")

      real == @root ? '' : real[(@root.length + 1)..]
    end

    def exists?(rel)
      @exists_cache[rel] ||= @files.include?(rel) || File.exist?(File.join(@root, rel))
    end

    def dir?(rel)
      File.directory?(File.join(@root, rel))
    end

    def size(rel)
      File.size(File.join(@root, rel))
    rescue SystemCallError
      0
    end
  end

  # ------------------------------------------------------------------
  # Extracting references
  # ------------------------------------------------------------------
  class Extractor
    Found = Struct.new(:kind, :raw, :line)

    def initialize(root, developer_links: false)
      @root = root
      @developer_links = developer_links
    end

    def extract(rel)
      text = read(rel)
      return [] unless text

      case rel
      when /\.html?\z/i then html_refs(text)
      when /\.topic\z/i then topic_refs(rel, text)
      when /\.css\z/i   then css_refs(text)
      when /\.js\z/i    then LinkAudit::SKIP_JS.any? { |re| re.match?(rel) } ? [] : js_refs(text)
      else []
      end
    end

    def read(rel)
      File.read(File.join(@root, rel), encoding: 'UTF-8').scrub
    rescue SystemCallError
      nil
    end

    # -- HTML ---------------------------------------------------------
    def html_refs(text)
      doc = Nokogiri::HTML5.parse(text)
      found = []
      doc.traverse do |node|
        next unless node.element?
        next if !@developer_links && developer_only?(node)

        collect_element(node, found)
      end
      found
    rescue StandardError
      []
    end

    # Links inside .todo/.comment blocks are hidden by css/bjc.css in
    # production, so they are not part of the live site.
    def developer_only?(node)
      node.ancestors.any? do |ancestor|
        ancestor['class'].to_s.split.intersect?(BJCCourse::DEVELOPER_CLASSES)
      end
    end

    def collect_element(node, found)
      line = node.line
      LinkAudit::LINK_ATTRS.each do |attr|
        add(found, "html:#{attr}", node[attr], line)
      end

      node['srcset']&.split(',')&.each do |candidate|
        add(found, 'html:srcset', candidate.strip.split(/\s+/).first, line)
      end

      if node.name == 'meta' && node['http-equiv'].to_s.casecmp('refresh').zero?
        add(found, 'html:meta-refresh', node['content'].to_s[LinkAudit::META_REFRESH, 1], line)
      end

      add(found, 'html:form-action', node['action'], line) if node.name == 'form'

      LinkAudit::TYPO_ATTRS.each do |typo, intended|
        add(found, "html:typo-#{typo}->#{intended}", node[typo], line)
      end

      # Inline handlers and <script> blocks build HTML strings containing
      # <img src=...>, and the redirect shims assign window.location.href.
      node.attributes.each do |name, attribute|
        scan_js(attribute.value, line, found) if name.start_with?('on')
      end
      scan_js(node.text, line, found) if node.name == 'script' && node['src'].nil?
    end

    def scan_js(text, line, found)
      seen = Set.new
      text.scan(LinkAudit::INLINE_ATTR) { |m| seen << m[0] }
      text.scan(LinkAudit::JS_PATH) { |m| seen << m[0] }
      seen.each { |value| add(found, 'html:inline-js', value, line) }
    end

    # -- .topic -------------------------------------------------------
    #
    # Delegates to BJCTopic so comment stripping, raw-html block termination and
    # llab's loose keyword matching are identical to the real build.
    def topic_refs(rel, text)
      topic = BJCTopic.new(File.join(@root, rel))
      parsed = topic.parse
      found = []
      finder = LineFinder.new(text)

      each_entry(parsed[:topics]) do |entry|
        if entry[:type] == 'raw-html'
          html_refs(entry[:content].to_s).each do |sub|
            found << Found.new("topic:raw-html/#{sub.kind}", sub.raw, finder.line_for(sub.raw))
          end
        elsif BJCTopic::RESOURCES_KEYWORDS.include?(entry[:type]) && !entry[:url].to_s.empty?
          found << Found.new("topic:#{entry[:type]}", entry[:url], finder.line_for(entry[:url]))
        end
      end
      found
    rescue StandardError => e
      [Found.new('topic:parse-error', e.message.to_s[0, 120], 1)]
    end

    def each_entry(nodes, &)
      Array(nodes).each do |node|
        next unless node.is_a?(Hash)

        yield(node)
        each_entry(node[:content], &) if node[:content].is_a?(Array)
      end
    end

    # -- CSS / JS -----------------------------------------------------
    def css_refs(text)
      found = []
      text.each_line.with_index(1) do |line, lineno|
        line.scan(LinkAudit::CSS_URL) do |m|
          value = m[0].strip
          add(found, 'css:url', value, lineno) unless value.downcase.start_with?('data:')
        end
      end
      found
    end

    def js_refs(text)
      found = []
      text.each_line.with_index(1) do |line, lineno|
        line.scan(LinkAudit::JS_PATH) do |m|
          value = m[0].strip
          # Bare extension literals -- curriculum.js does
          # `.replace('.html', '.es.html')` -- are not paths.
          next if value.split('/').last.to_s.start_with?('.')

          add(found, 'js:literal', value, lineno)
        end
      end
      found
    end

    def add(found, kind, value, line)
      return if value.nil?

      value = value.strip
      found << Found.new(kind, value, line) unless value.empty?
    end
  end

  # BJCTopic discards line numbers, so recover them by locating each URL in the
  # source, consuming matches in order so repeats map to successive lines.
  class LineFinder
    def initialize(text)
      @lines = text.each_line.to_a
      @cursor = Hash.new(0)
    end

    def line_for(needle)
      return 1 if needle.nil? || needle.empty?

      start = @cursor[needle]
      index = (start...@lines.length).find { |i| @lines[i].include?(needle) }
      index ||= (0...@lines.length).find { |i| @lines[i].include?(needle) }
      return 1 unless index

      @cursor[needle] = index + 1
      index + 1
    end
  end

  # ------------------------------------------------------------------
  # Turning a raw href into a repo path
  # ------------------------------------------------------------------
  class Resolver
    def initialize(inventory)
      @inv = inventory
    end

    # Returns any extra refs discovered in ?topic= / ?course= parameters.
    def resolve(ref)
      raw = ref.raw
      return finish(ref, 'skipped', 'fragment-only or empty') if raw.empty? || raw.start_with?('#')
      return finish(ref, 'external') if external?(raw)

      candidates = self.class.candidates(raw)
      first = candidates.first[0]
      return finish(ref, 'skipped', 'query/fragment only') if first.empty?

      if BARE_EXTERNAL.match?(first) && !KNOWN_EXT.match?(first)
        return finish(ref, 'missing-scheme',
                      'looks like an external host written without http(s)://')
      end

      pick(ref, candidates)
    end

    # Candidate (path, query) splits, best guess first.
    #
    # Snap! project links append flags with a bare `&` and no `?`, e.g.
    # `.../teachable-machine.xml&editMode`, so `&` has to act as a query
    # separator -- but some image filenames genuinely contain `&`, e.g.
    # `U1L3p7Graphic&Art3.gif`. The caller keeps whichever candidate exists.
    def self.candidates(url)
      url = url.split('#', 2).first.to_s
      if url.include?('?')
        path, query = url.split('?', 2)
        [[path, query.to_s]]
      elsif url.include?('&')
        path, query = url.split('&', 2)
        [[url, ''], [path, query.to_s]]
      else
        [[url, '']]
      end
    end

    private

    def external?(url)
      NON_FETCH.match?(url) || url.start_with?('//') || url.include?('://') ||
        url.match?(/\Ahttps?:/i)
    end

    def finish(ref, status, detail = nil)
      ref.status = status
      ref.detail = detail if detail
      []
    end

    def pick(ref, candidates)
      resolved = []
      chosen = nil

      candidates.each do |path, query|
        path = safe_unescape(path)
        rels = repo_paths(ref, path)
        return [] if rels.nil? # repo_paths already set the status

        rels.each do |rel|
          canonical = @inv.canonical(rel)
          return finish(ref, 'outside-repo', rel) if canonical.nil?

          resolved << [canonical, query]
          if @inv.exists?(canonical) || LinkAudit.ignored?(canonical)
            chosen = resolved.length - 1
            break
          end
        end
        break if chosen
      end

      return finish(ref, 'skipped', 'no resolvable path') if resolved.empty?

      # Nothing existed, so the link is broken either way: report whichever
      # candidate at least looks like a filename.
      chosen ||= resolved.index { |canonical, _q| KNOWN_EXT.match?(canonical) } ||
                 (resolved.length - 1)

      canonical, query = resolved[chosen]
      classify(ref, canonical)
      # Only trust ?topic= / ?course= when the base URL is a real repo page,
      # otherwise collegeboard.org/...?course=ap-computer-science-principles
      # reads as a BJC course reference.
      return [] unless !query.empty? && %w[ok dir].include?(ref.status)

      query_refs(ref, query)
    end

    # Decodes %XX but leaves `+` alone -- these are file paths, not form data,
    # and `U1L3p7Graphic+Art.gif` must not become `U1L3p7Graphic Art.gif`.
    def safe_unescape(path)
      URI::DEFAULT_PARSER.unescape(path)
    rescue StandardError
      path
    end

    def classify(ref, canonical)
      ref.target = canonical
      if LinkAudit.ignored?(canonical)
        ref.status = 'ignored-target'
      elsif @inv.exists?(canonical)
        ref.status = @inv.dir?(canonical) ? 'dir' : 'ok'
      elsif (actual = @inv.lower[canonical.downcase])
        ref.status = 'case-mismatch'
        ref.detail = "on disk as: #{actual}"
      else
        ref.status = 'missing'
      end
    end

    # Repo-relative paths this reference could mean, best guess first.
    def repo_paths(ref, path)
      return [normalize(path[WEB_ROOT.length..])] if path.start_with?(WEB_ROOT)

      if path.start_with?('/')
        # Site-absolute but outside /bjc-r/ (e.g. /mini17/bjc-r/..., /~cs10/...).
        finish(ref, 'outside-web-root', path)
        return nil
      end

      from_root = normalize(path)
      from_file = normalize(File.join(File.dirname(ref.source), path))

      # llab rewrites topic targets containing neither "/bjc-r/" nor ".." as
      # root-relative, NOT file-relative (llab/script/topic.js:306-319).
      return [from_root] if ref.kind.start_with?('topic:') && !path.include?('..')

      # A path literal in JS may be relative to the script or to llab.rootURL;
      # loader.js does both.
      return [from_file, from_root] if ref.kind.start_with?('js:')

      [from_file]
    end

    def normalize(path)
      File.expand_path(path, '/')[1..].to_s
    end

    # Hand-rolled rather than CGI/URI.decode_www_form: those reject or mangle
    # the flag-style params these URLs actually use ("...&novideo&noassignment")
    # and would turn `+` in a filename into a space.
    def parse_query(query)
      params = Hash.new { |hash, key| hash[key] = [] }
      query.split(/[&;]/).each do |pair|
        next if pair.empty?

        key, value = pair.split('=', 2)
        params[key] << value.to_s
      end
      params
    end

    def query_refs(ref, query)
      params = parse_query(query)
      out = []

      Array(params['topic']).each do |value|
        value = safe_unescape(value.to_s).strip
        next if value.empty?

        sub = Ref.new(source: ref.source, line: ref.line, raw: value, kind: 'query:topic')
        if value.end_with?('.topic')
          # llab.fetchTopicFile is plain concatenation onto /bjc-r/topic/.
          finish_query(sub, normalize("topic/#{value.delete_prefix('/')}"))
        else
          sub.status = 'malformed'
          sub.detail = '?topic= value is not a .topic path'
        end
        out << sub
      end

      Array(params['course']).each do |value|
        value = safe_unescape(value.to_s).split('#').first.to_s.strip
        next if value.empty? || value.include?('://') || !value.end_with?('.html')

        sub = Ref.new(source: ref.source, line: ref.line, raw: value, kind: 'query:course')
        finish_query(sub, normalize("course/#{value.delete_prefix('/')}"))
        out << sub
      end

      out
    rescue StandardError
      []
    end

    def finish_query(sub, rel)
      canonical = @inv.canonical(rel)
      if canonical.nil?
        sub.status = 'outside-repo'
        sub.detail = rel
      else
        classify(sub, canonical)
      end
    end
  end

  # ------------------------------------------------------------------
  # The graph
  # ------------------------------------------------------------------
  class Graph
    attr_reader :refs, :inbound, :outbound

    def initialize(inventory, extractor, resolver)
      @inv = inventory
      @extractor = extractor
      @resolver = resolver
      @refs = []
      @inbound = Hash.new { |h, k| h[k] = [] }
      @outbound = Hash.new { |h, k| h[k] = Set.new }
    end

    def build
      sources = @inv.files.select { |rel| PARSEABLE.match?(rel) && !LinkAudit.ignored?(rel) }
      sources.sort.each do |rel|
        @extractor.extract(rel).each do |found|
          ref = Ref.new(source: rel, line: found.line, raw: found.raw,
                        kind: found.kind, status: '', detail: '')
          extra = @resolver.resolve(ref)
          ([ref] + extra).each { |r| record(r) }
        end
      end
      self
    end

    def record(ref)
      @refs << ref
      return unless ref.target && %w[ok dir case-mismatch missing].include?(ref.status)

      @inbound[ref.target] << ref
      @outbound[ref.source] << ref.target if %w[ok dir].include?(ref.status)
    end

    def reachable
      seen = Set.new
      queue = []
      (ENTRY_POINTS + course_topic_files).each do |entry|
        canonical = @inv.canonical(entry)
        if canonical && @inv.exists?(canonical)
          queue << canonical if seen.add?(canonical)
        else
          warn "WARNING: entry point not found: #{entry}"
        end
      end

      until queue.empty?
        node = queue.shift
        @outbound[node].each do |target|
          queue << target if seen.add?(target)
        end
      end
      seen
    end

    # Ask BJCCourse what each course contains, rather than relying only on the
    # generic HTML crawl. course.rb already knows to skip `.topic_link`s with a
    # developer-only ancestor and to tolerate links carrying the wrong class,
    # so seeding from it keeps this audit's idea of "in a course" identical to
    # the build tools' -- and catches any topic the crawler would have missed.
    def course_topic_files
      COURSES.flat_map do |entry|
        BJCCourse.new(root: REPO_ROOT, **entry).list_topics.map do |topic|
          "topic/#{topic.split('&').first.delete_prefix('/')}"
        end
      rescue StandardError => e
        warn "WARNING: could not read course #{entry[:course]} (#{entry[:language]}): #{e.message}"
        []
      end.uniq
    end

    def referenced
      @inbound.each_with_object(Set.new) do |(target, refs), set|
        set << target if refs.any? { |r| %w[ok dir].include?(r.status) }
      end
    end
  end

  # ------------------------------------------------------------------
  # External links
  # ------------------------------------------------------------------
  class ExternalChecker
    POLICY = 'forbidden by network policy'
    UA = 'Mozilla/5.0 (compatible; bjc-link-audit/1.0)'

    def initialize(workers: 16, timeout: 15)
      @workers = workers
      @timeout = timeout
    end

    # Canonical fetch URL, or nil when the reference is malformed.
    def self.normalize(raw)
      return "https:#{raw}" if raw.start_with?('//')
      return raw if raw.include?('://')

      nil # e.g. action="http:diffways-soln.html" -- a scheme with no host
    end

    def check_all(urls)
      queue = Queue.new
      urls.each { |u| queue << u }
      results = {}
      mutex = Mutex.new

      workers = Array.new([@workers, urls.length].min.clamp(1, 64)) do
        Thread.new do
          while (url = begin
            queue.pop(true)
          rescue ThreadError
            nil
          end)
            outcome = check(url)
            mutex.synchronize { results[url] = outcome }
          end
        end
      end
      workers.each(&:join)
      results
    end

    def check(url)
      host = begin
        URI.parse(url).host
      rescue StandardError
        nil
      end
      # A localhost URL committed to the repo is a bug regardless of whether
      # anything happens to be listening here.
      return ['localhost', 'points at a local dev server'] if
        %w[localhost 127.0.0.1 0.0.0.0].include?(host)

      %w[HEAD GET].each do |method|
        status, detail, retry_with_get = request(url, method)
        next if retry_with_get && method == 'HEAD'

        return [status, detail]
      end
      ['unknown', 'no response']
    end

    private

    def request(url, method)
      uri = URI.parse(url)
      return ['malformed', 'no host', false] unless uri.host

      response = fetch(uri, method)
      interpret(response, method)
    rescue StandardError => e
      [*classify_error(e), false]
    end

    def fetch(uri, method)
      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == 'https',
                      open_timeout: @timeout, read_timeout: @timeout) do |http|
        request = (method == 'HEAD' ? Net::HTTP::Head : Net::HTTP::Get).new(uri, 'User-Agent' => UA)
        http.request(request)
      end
    end

    def interpret(response, method)
      code = response.code.to_i
      body = response.body.to_s[0, 512].downcase
      return ['blocked-by-policy', 'sandbox network policy; not checked', false] if
        body.include?(POLICY)

      case code
      when 200..399 then ['ok', code.to_s, false]
      when 404, 410 then ['broken', "HTTP #{code}", false]
      when 401, 403, 405 then ['forbidden', "HTTP #{code}", method == 'HEAD']
      else ['error', "HTTP #{code}", false]
      end
    end

    def classify_error(error)
      message = error.message.to_s
      return ['blocked-by-policy', 'sandbox network policy; not checked'] if
        message.downcase.include?(POLICY)
      return ['broken', "DNS failure: #{message}"] if
        message.match?(/not known|nodename nor servname|no address associated/i)
      return ['unknown', "timeout: #{message}"] if
        error.is_a?(Net::OpenTimeout) || error.is_a?(Net::ReadTimeout)

      ['unknown', "#{error.class}: #{message}"]
    end
  end

  # ------------------------------------------------------------------
  # Reporting
  # ------------------------------------------------------------------
  class Report
    def initialize(options)
      @options = options
      @out = options[:out]
      FileUtils.mkdir_p(@out)
    end

    def self.bucket(rel)
      parts = rel.split('/')
      return '(root)' if parts.length == 1
      return parts[0, 2].join('/') if
        %w[cur sparks topic llab utilities].include?(parts[0]) && parts.length > 2

      parts[0]
    end

    def write_csv(name, header, rows)
      CSV.open(File.join(@out, name), 'w') do |csv|
        csv << header
        rows.each { |row| csv << row }
      end
    end
  end

  # ------------------------------------------------------------------
  # Driver
  # ------------------------------------------------------------------
  class Runner
    # For anchor_id, so the anchors this checks stay tied to the ones the
    # summary generators emit.
    include BJCHelpers

    def initialize(options)
      @options = options
      @inv = Inventory.new(REPO_ROOT)
      @extractor = Extractor.new(REPO_ROOT, developer_links: options[:developer_links])
      @graph = Graph.new(@inv, @extractor, Resolver.new(@inv))
      @report = Report.new(options)
    end

    def run
      warn "Repo: #{REPO_ROOT}"
      warn "#{@inv.files.size} tracked files (#{@inv.symlinks.size} symlinks skipped)"

      @graph.build
      warn "#{@graph.refs.length} references extracted"

      @reachable = @graph.reachable
      warn "#{@reachable.size} files reachable from the #{ENTRY_POINTS.length} entry points"

      @referenced = @graph.referenced
      @candidates = @inv.files.reject { |rel| skip_candidate?(rel) }.sort

      broken = write_link_reports
      orphans, stranded = write_file_reports
      anchors = write_anchor_report
      external = write_external_report

      summary(broken, orphans, stranded, anchors, external)
    end

    private

    def skip_candidate?(rel)
      return true if LinkAudit.ignored?(rel)
      return true if !@options[:include_old] && LinkAudit.old_path?(rel)
      return true if !@options[:include_all] && LinkAudit.non_web?(rel)

      false
    end

    # An issue is only worth reporting if it lives in maintained content.
    def reportable_source?(rel)
      return false if !@options[:include_old] && LinkAudit.old_path?(rel)

      true
    end

    def live(rel)
      @reachable.include?(rel) ? 'yes' : 'no'
    end

    def write_link_reports
      broken = @graph.refs.select do |r|
        %w[missing case-mismatch].include?(r.status) && reportable_source?(r.source)
      end
      broken = broken.sort_by { |r| [r.source, r.line] }

      @report.write_csv(
        'broken-internal-links.csv',
        %w[source_file line link_as_written resolved_to problem detail
           source_reachable_from_course],
        broken.map { |r| [r.source, r.line, r.raw, r.target, r.status, r.detail, live(r.source)] }
      )

      unresolvable = @graph.refs.select do |r|
        %w[outside-web-root missing-scheme malformed].include?(r.status) &&
          reportable_source?(r.source)
      end
      unresolvable = unresolvable.sort_by { |r| [r.source, r.line] }
      @report.write_csv(
        'unresolvable-links.csv',
        %w[source_file line link_as_written problem detail source_reachable_from_course],
        unresolvable.map { |r| [r.source, r.line, r.raw, r.status, r.detail, live(r.source)] }
      )

      typos = @graph.refs.select { |r| r.kind.include?('typo-') && reportable_source?(r.source) }
      @report.write_csv(
        'attribute-typos.csv',
        %w[source_file line attribute value target_status],
        typos.map { |r| [r.source, r.line, r.kind.split('typo-').last, r.raw, r.status] }
      )

      errors = @graph.refs.select { |r| r.kind == 'topic:parse-error' }
      @report.write_csv('topic-parse-errors.csv', %w[topic_file message],
                        errors.map { |r| [r.source, r.raw] })

      @unresolvable = unresolvable
      @typos = typos
      @parse_errors = errors
      broken
    end

    def write_file_reports
      orphans = @candidates.reject { |r| @referenced.include?(r) || @reachable.include?(r) }
      @report.write_csv(
        'unreferenced-files.csv',
        %w[file area extension size_bytes],
        orphans.map { |r| [r, Report.bucket(r), File.extname(r).downcase, @inv.size(r)] }
      )

      stranded = @candidates.select { |r| @referenced.include?(r) && !@reachable.include?(r) }
      stranded_set = stranded.to_set
      @report.write_csv(
        'linked-but-not-in-a-course.csv',
        %w[file area extension inbound_link_count linking_files_also_stranded
           example_linking_files],
        stranded.map do |rel|
          srcs = @graph.inbound[rel].select { |r| %w[ok dir].include?(r.status) }
                       .map(&:source).uniq.sort
          [rel, Report.bucket(rel), File.extname(rel).downcase, srcs.length,
           srcs.count { |s| stranded_set.include?(s) }, srcs.first(5).join('; ')]
        end
      )

      [orphans, stranded]
    end

    def write_anchor_report
      return nil unless @options[:check_anchors]

      cache = {}
      rows = []
      @graph.refs.each do |r|
        next unless r.status == 'ok' && r.target && r.raw.include?('#')
        next unless reportable_source?(r.source) && !LinkAudit.old_path?(r.target)

        fragment = r.raw.split('#', 2)[1].to_s.split('?').first.to_s
        next if fragment.empty? || !r.target.match?(/\.html?\z/i)

        cache[r.target] ||= anchors_in(r.target)
        next if cache[r.target].include?(fragment)
        next if runtime_anchor_ok?(r.target, fragment)

        rows << [r.source, r.line, r.raw, r.target, fragment, live(r.source)]
      end

      @report.write_csv(
        'broken-anchors.csv',
        %w[source_file line link_as_written target_file missing_anchor
           source_reachable_from_course],
        rows
      )
      rows
    end

    def anchors_in(rel)
      text = @extractor.read(rel).to_s
      text.scan(/\b(?:id|name)\s*=\s*["']([^"']+)["']/).flatten.to_set
    end

    # `#vocab-3` is real if the target page has at least three vocab boxes: the
    # browser numbers them in document order at load time, so the ID is never in
    # the file. Anything past the count is a genuinely dangling link.
    def runtime_anchor_ok?(rel, fragment)
      @box_counts ||= {}
      counts = (@box_counts[rel] ||= count_boxes(rel))
      # Built with the generators' own anchor_id, so if that naming ever
      # changes this follows it rather than silently reporting false positives.
      counts.any? do |type, count|
        (1..count).any? { |number| anchor_id(type, number) == fragment }
      end
    end

    def count_boxes(rel)
      doc = Nokogiri::HTML5.parse(@extractor.read(rel).to_s)
      RUNTIME_ANCHORS.transform_values { |selector| doc.css(selector).length }
    rescue StandardError
      RUNTIME_ANCHORS.transform_values { 0 }
    end

    def write_external_report
      return nil unless @options[:external]

      malformed = {}
      by_url = Hash.new { |h, k| h[k] = [] }
      @graph.refs.each do |r|
        next unless r.status == 'external' && !NON_FETCH.match?(r.raw)
        next unless reportable_source?(r.source)

        url = ExternalChecker.normalize(r.raw)
        if url
          by_url[url] << r
        else
          malformed[r.raw] = ['malformed', 'scheme without a host']
          by_url[r.raw] << r
        end
      end

      urls = by_url.keys.reject { |u| malformed.key?(u) }.sort
      warn "Checking #{urls.length} distinct external URLs " \
           "(#{malformed.length} malformed, not fetched)..."
      results = ExternalChecker.new(workers: @options[:workers],
                                    timeout: @options[:timeout]).check_all(urls)
      results.merge!(malformed)

      rows = []
      counts = Hash.new(0)
      results.keys.sort.each do |url|
        status, detail = results[url]
        counts[status] += 1
        next if status == 'ok'

        by_url[url].sort_by { |r| [r.source, r.line] }.each do |r|
          rows << [url, status, detail, r.source, r.line, live(r.source)]
        end
      end

      @report.write_csv(
        'external-links.csv',
        %w[url status detail source_file line source_reachable_from_course],
        rows
      )
      counts
    end

    def summary(broken, orphans, stranded, anchors, external)
      lines = []
      lines << "# bjc-r link audit\n"
      lines << "- Tracked files scanned: **#{@inv.files.size}** " \
               '(ignored: `docs/`, `cur/blown-to-bits.html`)'
      lines << "- References extracted: **#{@graph.refs.length}**"
      lines << "- Files reachable from the 6 entry points: **#{@reachable.size}**"
      lines << "- Files considered for orphan analysis: **#{@candidates.length}**"
      unless @options[:include_old]
        skipped = @inv.files.count { |r| LinkAudit.old_path?(r) }
        lines << "- Ignored as archived `old` paths: **#{skipped}** " \
                 '(still crawled, never reported)'
      end
      lines << ''
      lines << '## 1. Broken internal links'
      lines << "- Missing target: **#{broken.count { |r| r.status == 'missing' }}**"
      lines << '- Case-only mismatch (works on macOS, 404s on the server): ' \
               "**#{broken.count { |r| r.status == 'case-mismatch' }}**"
      lines << "- Unresolvable (outside `/bjc-r/`, missing scheme, malformed): **#{@unresolvable.length}**"
      lines << "- Typo'd link attributes: **#{@typos.length}**"
      lines << "- `.topic` files that failed to parse: **#{@parse_errors.length}**"
      lines << "- Of the broken links, **#{broken.count { |r| @reachable.include?(r.source) }}** " \
               'are on pages reachable from a course.'
      lines << ''
      lines << '## 2. Files not linked from anywhere'
      lines.concat(area_breakdown(orphans))
      lines << '## 3. Linked, but not reachable from a course or teacher guide'
      lines.concat(area_breakdown(stranded))
      lines << "## Broken `#anchors`\n- Total: **#{anchors.length}**\n" if anchors
      if external
        lines << '## External links'
        external.sort_by { |_s, c| -c }.each { |status, count| lines << "- #{status}: **#{count}**" }
        lines << ''
      end
      lines << "CSVs written to `#{@options[:out]}/`."

      text = "#{lines.join("\n")}\n"
      File.write(File.join(@options[:out], 'report.md'), text)
      puts text
    end

    def area_breakdown(files)
      lines = ["- Total: **#{files.length}**"]
      counts = Hash.new(0)
      files.each { |rel| counts[Report.bucket(rel)] += 1 }
      counts.sort_by { |_area, count| -count }.first(15).each do |area, count|
        lines << "  - `#{area}/`: #{count}"
      end
      lines << ''
      lines
    end
  end

  def self.parse_options(argv)
    options = { out: 'link-audit-out', external: false, check_anchors: false,
                include_all: false, include_old: false, developer_links: false,
                workers: 16, timeout: 15 }
    OptionParser.new do |opts|
      opts.banner = 'Usage: bundle exec ruby utilities/build-tools/link-audit.rb [options]'
      opts.on('--out DIR', 'Output directory') { |v| options[:out] = v }
      opts.on('--external', 'Also check external URLs') { options[:external] = true }
      opts.on('--check-anchors', 'Also validate #fragments') { options[:check_anchors] = true }
      opts.on('--include-all', 'Do not skip build tooling / tests') { options[:include_all] = true }
      opts.on('--include-old', 'Do not skip archived old/ paths') { options[:include_old] = true }
      opts.on('--developer-links', 'Follow links inside .todo/.comment blocks') do
        options[:developer_links] = true
      end
      opts.on('--workers N', Integer, 'External check concurrency') { |v| options[:workers] = v }
      opts.on('--timeout N', Float, 'External check timeout (s)') { |v| options[:timeout] = v }
    end.parse!(argv)
    options
  end
end

LinkAudit::Runner.new(LinkAudit.parse_options(ARGV)).run if $PROGRAM_NAME == __FILE__
