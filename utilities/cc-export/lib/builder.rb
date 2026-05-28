# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'nokogiri'
require 'set'

require_relative '../../build-tools/bjc_helpers'
require_relative '../../build-tools/course'
require_relative '../../build-tools/topic'
require_relative 'assignment_template'
require_relative 'cartridge'
require_relative 'copy_resources'
require_relative 'manifest_writer'
require_relative 'page_inspector'
require_relative 'quiz_extractor'

module CCExport
  # Builds an in-memory Cartridge from a course configuration. Reuses
  # BJCCourse (to discover the topic files and their display titles from the
  # course HTML) and BJCTopic (to parse each .topic file's headings and
  # resources). All assignment-list, sidebar, and mode handling lives here.
  class Builder
    MODES = %w[iframe copy].freeze

    attr_reader :config, :bjc_root, :mode

    def initialize(config:, bjc_root:, mode:)
      raise ArgumentError, "Unknown mode: #{mode}" unless MODES.include?(mode)

      @config   = config
      @bjc_root = bjc_root
      @mode     = mode
    end

    # Materialise the cartridge into `staging_dir` (manifest + per-resource XML
    # + any copy-mode HTML/assets). Returns the in-memory Cartridge so callers
    # can inspect it (e.g. for tests).
    def build_into(staging_dir)
      FileUtils.mkdir_p(staging_dir)

      cart = Cartridge.new(
        identifier: config.fetch('identifier'),
        title: config.fetch('title'),
        description: config['description'].to_s,
        language: config['language'] || 'en'
      )

      copier = (mode == 'copy') ? CopyResources.new(bjc_root, staging_dir) : nil

      build_sidebar_module(cart, staging_dir)
      assignments_by_topic = group_assignments_by_topic
      build_topic_modules(cart, staging_dir, copier, assignments_by_topic)
      build_orphan_assignments_module(cart, staging_dir, assignments_by_topic)
      warn_unknown_topic_assignments(assignments_by_topic)

      manifest = ManifestWriter.build_manifest(cart)
      File.write(File.join(staging_dir, 'imsmanifest.xml'), manifest)
      cart
    end

    private

    def build_sidebar_module(cart, staging_dir)
      sidebar = config['sidebar_links'] || []
      return if sidebar.empty?

      mod = OrgItem.new(id: stable_id('mod', 'sidebar'), title: 'BJC Resources')
      sidebar.each do |link_cfg|
        link = WebLink.new(
          id: stable_id('wl', 'sidebar', link_cfg['title']),
          title: link_cfg['title'],
          url: absolute_url(link_cfg['url']),
          target: link_cfg['target'] || '_blank'
        )
        cart.weblinks << link
        ManifestWriter.write_weblink(staging_dir, link)
        mod.children << OrgItem.new(id: stable_id('it', link.id), title: link.title, ref: link.id)
      end
      cart.modules << mod
    end

    def group_assignments_by_topic
      groups = Hash.new { |h, k| h[k] = [] }
      (config['assignments'] || []).each do |a|
        groups[a['topic']] << a
      end
      groups
    end

    def build_topic_modules(cart, staging_dir, copier, assignments_by_topic)
      seen = Set.new
      list_topic_refs.each do |ref|
        next if seen.include?(ref[:path])

        topic_file = File.join(bjc_root, 'topic', ref[:path])
        unless File.exist?(topic_file)
          warn "WARN: topic file not found, skipping: #{topic_file}"
          next
        end
        seen << ref[:path]

        bjc_topic = BJCTopic.new(topic_file, course: course_basename, language: course_language)
        parsed = bjc_topic.parse
        mod_title = ref[:title].to_s.strip
        mod_title = parsed[:title].to_s.strip if mod_title.empty?
        mod = OrgItem.new(id: stable_id('mod', ref[:path]), title: mod_title)

        topic_payload = (parsed[:topics] || []).first || {}
        (topic_payload[:content] || []).each do |entry|
          if entry[:type] == 'section'
            section_node = section_org_item(mod, entry)
            (entry[:content] || []).each do |sub|
              add_resource(sub, mod: mod, section: section_node, topic_path: ref[:path], cart: cart, staging_dir: staging_dir, copier: copier)
            end
          else
            add_resource(entry, mod: mod, section: nil, topic_path: ref[:path], cart: cart, staging_dir: staging_dir, copier: copier)
          end
        end

        (assignments_by_topic.delete(ref[:path]) || []).each do |a_cfg|
          add_assignment(a_cfg, mod: mod, cart: cart, staging_dir: staging_dir)
        end

        cart.modules << mod
      end
    end

    def build_orphan_assignments_module(cart, staging_dir, assignments_by_topic)
      leftover = assignments_by_topic.delete(nil) || []
      return if leftover.empty?

      mod = OrgItem.new(id: stable_id('mod', 'assignments'), title: 'Course Assignments')
      leftover.each { |a_cfg| add_assignment(a_cfg, mod: mod, cart: cart, staging_dir: staging_dir) }
      cart.modules << mod
    end

    def warn_unknown_topic_assignments(assignments_by_topic)
      assignments_by_topic.each do |topic_path, items|
        items.each do |item|
          warn "WARN: assignment '#{item['id']}' references unknown topic '#{topic_path}'"
        end
      end
    end

    def section_org_item(mod, entry)
      heading = entry[:title].to_s.strip
      return nil if heading.empty?

      section = OrgItem.new(id: stable_id('sec', mod.id, heading), title: strip_html(heading))
      mod.children << section
      section
    end

    def add_resource(entry, mod:, section:, topic_path:, cart:, staging_dir:, copier:)
      type = entry[:type].to_s
      return unless BJCTopic::RESOURCES_KEYWORDS.include?(type)

      url = entry[:url]
      return if url.nil? || url.to_s.empty?

      title = strip_html(entry[:content].to_s)
      title = url if title.empty?
      container = section || mod
      info = page_inspector.info_for(url)

      # Quiz pages → CC QTI assessment (when enabled).
      if auto_quizzes_enabled? && (type == 'quiz' || info&.quiz?)
        return if attach_quiz(container, title, url, topic_path, cart, staging_dir, info)
      end

      # Student-work pages → CC assignment with link + submission instructions.
      if auto_assignments_enabled? && info&.student_work? &&
         !topic_skipped_from_auto?(topic_path) &&
         !blocked_from_auto_assignment?(url)
        attach_auto_assignment(container, title, url, topic_path, cart, staging_dir)
        return
      end

      if mode == 'iframe'
        attach_weblink(container, title, url, topic_path, cart, staging_dir)
      else
        attach_copied_page(container, title, url, topic_path, cart, staging_dir, copier)
      end
    end

    # Wires a self-check HTML page into the cartridge as a real QTI quiz.
    # Returns true when a quiz was attached, false if we should fall back
    # (no parseable items found, or page missing).
    def attach_quiz(container, title, url, topic_path, cart, staging_dir, info)
      info ||= page_inspector.info_for(url)
      return false if info.nil? || !info.quiz?

      quiz_id = stable_id('quiz', topic_path, url)
      quiz = QuizExtractor.extract(info.raw_html, quiz_id: quiz_id, title: title)
      return false if quiz.questions.empty?

      resource = QuizResource.new(id: quiz_id, title: title, quiz: quiz)
      cart.quizzes << resource
      ManifestWriter.write_quiz(staging_dir, resource)
      container.children << OrgItem.new(id: stable_id('it', resource.id), title: title, ref: resource.id)
      true
    end

    # Wires a "student work" page (one with <div class="forYouToDo">) into the
    # cartridge as an LMS assignment with a description that links back to the
    # page and tells students how to submit.
    def attach_auto_assignment(container, title, url, topic_path, cart, staging_dir)
      page_url = absolute_url(url)
      body = AssignmentTemplate.build(title: title, page_url: page_url, language: course_language)
      assignment = Assignment.new(
        id: stable_id('aa', topic_path, url),
        title: title,
        body_html: body,
        points: auto_assignment_points,
        submission_types: auto_assignment_submission_types
      )
      cart.assignments << assignment
      ManifestWriter.write_assignment(staging_dir, assignment)
      container.children << OrgItem.new(id: stable_id('it', assignment.id), title: assignment.title, ref: assignment.id)
    end

    def attach_weblink(container, title, url, topic_path, cart, staging_dir)
      link = WebLink.new(
        id: stable_id('wl', topic_path, url),
        title: title,
        url: absolute_url(url),
        target: '_blank'
      )
      cart.weblinks << link
      ManifestWriter.write_weblink(staging_dir, link)
      container.children << OrgItem.new(id: stable_id('it', link.id), title: link.title, ref: link.id)
    end

    def attach_copied_page(container, title, url, topic_path, cart, staging_dir, copier)
      primary, extras = copier.copy_page(url)
      wc = WebContent.new(id: stable_id('wc', topic_path, url), href: primary, extra_files: extras)
      cart.webcontents << wc
      container.children << OrgItem.new(id: stable_id('it', wc.id), title: title, ref: wc.id)
    rescue Errno::ENOENT => e
      warn "WARN: #{e.message}; falling back to web link for #{url}"
      attach_weblink(container, title, url, topic_path, cart, staging_dir)
    end

    def add_assignment(a_cfg, mod:, cart:, staging_dir:)
      a_id = a_cfg['id'] || slugify(a_cfg['title'])
      assignment = Assignment.from_plain_text(
        id: stable_id('a', a_id),
        title: a_cfg.fetch('title'),
        description: a_cfg['description'],
        points: a_cfg['points'] || 0,
        submission_types: a_cfg['submission_types'] || ['online_upload']
      )
      cart.assignments << assignment
      ManifestWriter.write_assignment(staging_dir, assignment)
      mod.children << OrgItem.new(id: stable_id('it', assignment.id), title: assignment.title, ref: assignment.id)
    end

    # ----- Auto-features (quizzes + per-page assignments) -------------------

    def auto_quizzes_enabled?
      cfg = config['auto_quizzes']
      cfg.is_a?(Hash) ? cfg.fetch('enabled', true) : !!cfg
    end

    def auto_assignments_enabled?
      cfg = config['auto_assignments']
      cfg.is_a?(Hash) ? cfg.fetch('enabled', true) : !!cfg
    end

    def auto_assignment_points
      cfg = config['auto_assignments']
      (cfg.is_a?(Hash) ? cfg['points'] : nil) || 10
    end

    def auto_assignment_submission_types
      cfg = config['auto_assignments']
      list = cfg.is_a?(Hash) ? cfg['submission_types'] : nil
      list || %w[online_text_entry online_upload]
    end

    # Lets a config exclude specific topic-files or URL patterns from auto-
    # assignment generation (e.g. a video-only page that happens to have a
    # `forYouToDo` box for "discuss this clip").
    def blocked_from_auto_assignment?(url)
      cfg = config['auto_assignments']
      return false unless cfg.is_a?(Hash)

      excludes = cfg['exclude_urls'] || []
      excludes.any? { |pat| File.fnmatch(pat, url, File::FNM_PATHNAME) || url.include?(pat) }
    end

    # Suppress per-page auto-assignments inside a topic whose work is already
    # tracked by one or more high-stakes manual assignments (e.g. the AP
    # Create Task — practice + official cover the eight pages end-to-end).
    def topic_skipped_from_auto?(topic_path)
      cfg = config['auto_assignments']
      return false unless cfg.is_a?(Hash)

      skip = cfg['skip_topics'] || []
      skip.include?(topic_path)
    end

    def page_inspector
      @page_inspector ||= PageInspector.new(bjc_root)
    end

    # ----- Course/topic discovery via BJCCourse ----------------------------

    def bjc_course
      @bjc_course ||= BJCCourse.new(
        root: bjc_root,
        course: course_basename,
        language: course_language
      )
    end

    def course_basename
      base = File.basename(config.fetch('course_file'), '.html')
      base.sub(/\.\w\w\z/, '')
    end

    def course_language
      config['language'] || 'en'
    end

    # Returns [{ title:, path: }, ...] in the order the course HTML lists them.
    # BJCCourse.list_topics returns paths but loses anchor titles; we walk the
    # already-parsed Nokogiri doc on BJCCourse to recover them.
    def list_topic_refs
      doc = bjc_course.course_contents
      seen = Set.new
      doc.css('.topic_link a').filter_map do |node|
        href = node['href'].to_s
        next unless bjc_course.has_topic_url?(href)

        path = href.split('?topic=', 2)[1].to_s.split('&').first
        next if path.nil? || path.empty? || seen.include?(path)

        seen << path
        title = (node['title'] || node.text).to_s.strip
        { title: title.empty? ? path : title, path: path }
      end
    end

    # ----- URL/string helpers ----------------------------------------------

    def absolute_url(url)
      return url if url.match?(%r{\Ahttps?://}) || url.start_with?('mailto:')
      return "https:#{url}" if url.start_with?('//')

      base = config['base_url'].to_s.chomp('/')
      url.start_with?('/') ? "#{base}#{url}" : "#{base}/#{url}"
    end

    def stable_id(prefix, *parts)
      digest = Digest::SHA1.hexdigest([config['identifier'], *parts].join('|'))[0, 16]
      "#{prefix}_#{digest}"
    end

    def strip_html(string)
      return '' if string.nil?

      Nokogiri::HTML.fragment(string).text.strip
    end

    def slugify(string)
      string.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/(\A-|-\z)/, '')
    end
  end
end
