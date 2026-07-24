# frozen_string_literal: true

# Plain-data structs that describe an in-memory Common Cartridge before it gets
# serialised to imsmanifest.xml. The objects here intentionally know nothing
# about XML — `ManifestWriter` turns them into bytes.

module CCExport
  WebLink = Struct.new(:id, :title, :url, :target, keyword_init: true) do
    def initialize(target: '_blank', **rest)
      super(target: target, **rest)
    end
  end

  WebContent = Struct.new(:id, :href, :extra_files, keyword_init: true) do
    def initialize(extra_files: [], **rest)
      super(extra_files: extra_files, **rest)
    end
  end

  # `body_html` is the HTML that goes into the LMS assignment description.
  # When callers have plain text, they should use `Assignment.from_plain_text`
  # to get a Cartridge-ready instance; when they have HTML already (e.g. from
  # AssignmentTemplate) they pass it directly.
  Assignment = Struct.new(
    :id, :title, :body_html, :points, :submission_types,
    keyword_init: true
  ) do
    def initialize(points: 0.0, submission_types: %w[online_upload], body_html: '', **rest)
      super(points: points.to_f, submission_types: submission_types, body_html: body_html, **rest)
    end

    def self.from_plain_text(id:, title:, description:, points: 0, submission_types: %w[online_upload])
      body = if description.nil? || description.strip.empty?
               ''
             else
               escaped = description.strip
                                    .gsub('&', '&amp;')
                                    .gsub('<', '&lt;')
                                    .gsub('>', '&gt;')
               escaped.split(/\n\s*\n/).map { |p| "<p>#{p.gsub("\n", '<br/>')}</p>" }.join
             end
      new(id: id, title: title, body_html: body, points: points, submission_types: submission_types)
    end
  end

  # An org-tree node. A "module" is the top-level container, a "section" lives
  # inside a module, and a leaf "item" carries `ref` (the identifier of a
  # WebLink / WebContent / Assignment resource).
  OrgItem = Struct.new(:id, :title, :ref, :children, keyword_init: true) do
    def initialize(children: [], ref: nil, **rest)
      super(children: children, ref: ref, **rest)
    end

    def leaf?
      children.empty?
    end
  end

  # A quiz resource backed by a QTI 1.2 assessment XML file inside the
  # cartridge. `quiz` is a QuizExtractor::Quiz; the builder generates the
  # XML and writes it to `<id>/<id>.xml`.
  QuizResource = Struct.new(:id, :title, :quiz, keyword_init: true) do
    def href
      "#{id}/#{id}.xml"
    end
  end

  class Cartridge
    attr_accessor :identifier, :title, :description, :language
    attr_reader :modules, :weblinks, :webcontents, :assignments, :quizzes

    def initialize(identifier:, title:, description: '', language: 'en')
      @identifier   = identifier
      @title        = title
      @description  = description
      @language     = language
      @modules      = []
      @weblinks     = []
      @webcontents  = []
      @assignments  = []
      @quizzes      = []
    end
  end
end
