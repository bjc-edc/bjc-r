# frozen_string_literal: true

# Smoke specs for the Common Cartridge exporter. Focused: confirms that the
# exporter glues BJCCourse / BJCTopic / config -> a valid .imscc package that
# (a) contains the manifest, (b) lists each unit topic as a module with the
# expected pages, (c) carries the AP Create Task assignments, and (d) emits
# only well-formed XML.

require 'nokogiri'
require 'tmpdir'
require 'yaml'

# BJC source files are UTF-8; match the CLI's behaviour so the specs pass even
# when LANG is unset (e.g. in some CI environments).
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require_relative '../../cc-export/lib/builder'
require_relative '../../cc-export/lib/manifest_writer'
require_relative '../../cc-export/lib/packager'
require_relative '../../cc-export/lib/quiz_extractor'
require_relative '../../cc-export/lib/qti_writer'

REPO_ROOT = File.expand_path('../../..', __dir__)

def build_csp_cartridge(staging:, mode: 'iframe', overrides: {})
  config = YAML.load_file(File.join(REPO_ROOT, 'utilities/cc-export/configs/csp.yml')).merge(overrides)
  builder = CCExport::Builder.new(config: config, bjc_root: REPO_ROOT, mode: mode)
  [builder.build_into(staging), config]
end

RSpec.describe CCExport::Builder do
  it 'discovers all CSP units and the Create Task from the course HTML' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)

      module_titles = cart.modules.map(&:title)
      expect(module_titles).to include(
        'BJC Resources',
        'Unit 1: Introduction to Programming',
        'Unit 8: Recursive Functions'
      )
      expect(module_titles).to include(a_string_matching(/Create Task/))
    end
  end

  it 'preserves section headings that contain inner colons' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)

      unit1 = cart.modules.find { |m| m.title.start_with?('Unit 1:') }
      section_titles = unit1.children.map(&:title)
      expect(section_titles).to include('Lab 1: Click Alonzo Game', 'Lab 2: Gossip')
    end
  end

  it 'places assignments inside the topic module they reference' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)

      create_task_mod = cart.modules.find { |m| m.title.match?(/Create Task/) }
      # The Create Task topic is in `skip_topics`, so its module should ONLY
      # contain the two high-stakes manual assignments — not per-page autos.
      manual_titles = create_task_mod.children
                                     .select { |c| c.ref&.start_with?('a_') }
                                     .map(&:title)
      auto_titles = create_task_mod.children
                                   .select { |c| c.ref&.start_with?('aa_') }
                                   .map(&:title)
      expect(manual_titles).to contain_exactly(
        'AP Create Task — Practice (with PPR draft)',
        'AP Create Task — Official Submission (with PPR)'
      )
      expect(auto_titles).to be_empty
    end
  end

  it 'emits Canvas-namespace assignment XML with the right metadata' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)

      practice = cart.assignments.find { |a| a.title.include?('Practice') }
      assignment_path = File.join(staging, CCExport::ManifestWriter.assignment_settings_path(practice))
      doc = Nokogiri::XML(File.read(assignment_path))
      doc.remove_namespaces!

      expect(doc.at_xpath('/assignment/title').text).to eq(practice.title)
      expect(doc.at_xpath('/assignment/points_possible').text).to eq('50.0')
      expect(doc.at_xpath('/assignment/submission_types').text).to eq('online_upload,online_text_entry')
      expect(doc.at_xpath('/assignment/workflow_state').text).to eq('published')
    end
  end

  it 'emits a manifest where every item identifierref resolves to a resource' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)

      manifest = CCExport::ManifestWriter.build_manifest(cart)
      doc = Nokogiri::XML(manifest)
      doc.remove_namespaces!

      resource_ids = doc.xpath('//resource').map { |r| r['identifier'] }.to_set
      referenced = doc.xpath('//item[@identifierref]').map { |r| r['identifierref'] }
      expect(referenced).not_to be_empty
      expect(referenced.uniq - resource_ids.to_a).to be_empty
    end
  end

  it 'absolutizes /bjc-r/ web link URLs against base_url' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)

      sidebar = cart.weblinks.find { |w| w.title == 'Snap! Cheat Sheet' }
      expect(sidebar.url).to eq('https://bjc.edc.org/bjc-r/cur/snap-cheat-sheet.html')
    end
  end

  it 'produces deterministic identifiers across runs' do
    ids = (1..2).map do
      Dir.mktmpdir do |staging|
        cart, = build_csp_cartridge(staging: staging)
        cart.modules.map(&:id)
      end
    end
    expect(ids[0]).to eq(ids[1])
  end

  it 'zips into an imscc file Canvas can open (well-formed XML throughout)' do
    Dir.mktmpdir do |staging|
      Dir.mktmpdir do |out_dir|
        build_csp_cartridge(staging: staging)
        out = File.join(out_dir, 'test.imscc')
        CCExport::Packager.write_imscc(staging, out)

        expect(File.size(out)).to be > 1024
        # `unzip -t` would also work, but checking XML files is more useful.
        Dir.glob(File.join(staging, '**/*.xml')).each do |f|
          expect { Nokogiri::XML(File.read(f)) { |c| c.strict } }.not_to raise_error, f
        end
      end
    end
  end
end

RSpec.describe 'CSP and Spanish CSP have parallel assignment lists' do
  it 'matches assignment ids and counts between csp.yml and csp-es.yml' do
    en = YAML.load_file(File.join(REPO_ROOT, 'utilities/cc-export/configs/csp.yml'))
    es = YAML.load_file(File.join(REPO_ROOT, 'utilities/cc-export/configs/csp-es.yml'))

    en_ids = en.fetch('assignments').map { |a| a['id'] }.sort
    es_ids = es.fetch('assignments').map { |a| a['id'] }.sort
    expect(es_ids).to eq(en_ids)

    en_points = en['assignments'].map { |a| [a['id'], a['points']] }.to_h
    es_points = es['assignments'].map { |a| [a['id'], a['points']] }.to_h
    expect(es_points).to eq(en_points)
  end
end

# Spec covering the topic.rb get_content fix: heading lines with inner colons
# must keep their full text. Lives here (not in a topic-only spec) because the
# CC exporter is the consumer that triggered the fix.
RSpec.describe 'BJCTopic heading parsing (post-fix)' do
  require_relative '../../build-tools/topic'

  it 'keeps inner colons in heading titles' do
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'inner-colon.topic')
      File.write(file, <<~TOPIC)
        title: Sample

        {
        heading: Lab 1: Click Alonzo Game
          resource: First Page [/bjc-r/cur/x.html]
        }
      TOPIC

      parsed = BJCTopic.new(file).parse
      section = parsed[:topics].first[:content].first
      expect(section[:title]).to eq('Lab 1: Click Alonzo Game')
    end
  end
end

RSpec.describe CCExport::QuizExtractor do
  it 'parses a single-answer multiple-choice question with feedback' do
    html = <<~HTML
      <div class="assessment-data" type="multiplechoice" identifier="Q1" maxchoices="1" responseidentifier="ri7" shuffle="false">
        <div class="prompt">
          <div class="ap-standard">AAP-3.E</div>
          What is 2 + 2?
        </div>
        <div class="choice" identifier="c1">
          <div class="text">3</div>
          <div class="feedback">Not quite — try again.</div>
        </div>
        <div class="choice" identifier="c2">
          <div class="text">4</div>
          <div class="feedback">Correct!</div>
        </div>
        <div class="responseDeclaration" identifier="ri7">
          <div class="correctResponse" identifier="c2"></div>
        </div>
      </div>
    HTML

    quiz = CCExport::QuizExtractor.extract(html, quiz_id: 'q1', title: 'Sample')
    expect(quiz.questions.length).to eq(1)
    q = quiz.questions.first
    expect(q.id).to eq('ri7')
    expect(q.correct_ids).to eq(['c2'])
    expect(q.multiple_response).to be false
    expect(q.ap_standard).to eq('AAP-3.E')
    expect(q.stem_html).to include('What is 2 + 2?')
    expect(q.stem_html).not_to include('AAP-3.E') # ap-standard pulled out as metadata
    expect(q.choices.map(&:id)).to eq(%w[c1 c2])
    expect(q.choices[1].feedback_html).to include('Correct!')
  end

  it 'parses a multi-answer question (maxchoices > 1)' do
    html = <<~HTML
      <div class="assessment-data" type="multiplechoice" maxchoices="2" responseidentifier="ri9">
        <div class="prompt">Pick the even numbers.</div>
        <div class="choice" identifier="c1"><div class="text">1</div></div>
        <div class="choice" identifier="c2"><div class="text">2</div></div>
        <div class="choice" identifier="c3"><div class="text">4</div></div>
        <div class="responseDeclaration" identifier="ri9">
          <div class="correctResponse" identifier="c2"></div>
          <div class="correctResponse" identifier="c3"></div>
        </div>
      </div>
    HTML
    quiz = CCExport::QuizExtractor.extract(html, quiz_id: 'q', title: 't')
    q = quiz.questions.first
    expect(q.multiple_response).to be true
    expect(q.correct_ids).to contain_exactly('c2', 'c3')
  end

  it 'extracts every question from the real Unit 1 self-check page' do
    html = File.read(File.join(REPO_ROOT, 'cur/programming/1-introduction/unit-1-self-check.html'),
                     mode: 'r:UTF-8', invalid: :replace, undef: :replace)
    quiz = CCExport::QuizExtractor.extract(html, quiz_id: 'u1', title: 'Unit 1 Self-Check')

    # Unit 1's self-check page has 18 assessment-data blocks today; treat
    # 15+ as the lower bound so the spec doesn't break on routine additions.
    expect(quiz.questions.length).to be >= 15
    expect(quiz.questions.map(&:id).uniq.length).to eq(quiz.questions.length),
                                                    'response identifiers should be unique'
    expect(quiz.questions.all? { |q| q.correct_ids.any? }).to be true
  end
end

RSpec.describe CCExport::QtiWriter do
  let(:quiz) do
    CCExport::QuizExtractor::Quiz.new(
      id: 'q1', title: 'Sample',
      questions: [
        CCExport::QuizExtractor::Question.new(
          id: 'ri1', title: 'Two plus two',
          stem_html: '<p>What is 2 + 2?</p>',
          choices: [
            CCExport::QuizExtractor::Choice.new(id: 'c1', text_html: '3', feedback_html: 'Nope'),
            CCExport::QuizExtractor::Choice.new(id: 'c2', text_html: '4', feedback_html: 'Yes!')
          ],
          correct_ids: ['c2'], shuffle: false, multiple_response: false, ap_standard: 'AAP-3.E'
        )
      ]
    )
  end

  it 'emits a well-formed QTI 1.2 assessment document' do
    xml = CCExport::QtiWriter.build_assessment_xml(quiz)
    doc = Nokogiri::XML(xml) { |c| c.strict }
    doc.remove_namespaces!

    expect(doc.at_xpath('/questestinterop/assessment')['ident']).to eq('q1')
    expect(doc.xpath('//item').length).to eq(1)
    expect(doc.at_xpath('//response_lid')['rcardinality']).to eq('Single')
    expect(doc.xpath('//response_label').map { |n| n['ident'] }).to eq(%w[c1 c2])
    correct = doc.at_xpath('//respcondition[@continue="No"]//varequal').text
    expect(correct).to eq('c2')
    expect(doc.xpath('//itemfeedback').length).to eq(2) # one per choice
  end

  it 'uses an <and>/<not> resprocessing block for multi-select questions' do
    multi = quiz.dup
    multi.questions.first.multiple_response = true
    multi.questions.first.correct_ids = ['c2']
    xml = CCExport::QtiWriter.build_assessment_xml(multi)
    doc = Nokogiri::XML(xml)
    doc.remove_namespaces!
    expect(doc.at_xpath('//respcondition[@continue="No"]/conditionvar/and')).not_to be_nil
    expect(doc.at_xpath('//respcondition[@continue="No"]//not')).not_to be_nil
  end
end

RSpec.describe 'auto-assignments and auto-quizzes' do
  it 'produces at least one quiz and many auto-assignments for CSP' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)
      expect(cart.quizzes.length).to be >= 5
      auto_assignments = cart.assignments.reject { |a| a.id.start_with?('a_') }
      # ~80 lab pages per unit × 8 units, with summary pages filtered out.
      # We assert a generous lower bound so additions to the curriculum don't
      # break the spec.
      expect(auto_assignments.length).to be >= 50
    end
  end

  it 'auto-assignment descriptions link to the BJC page and ask for Snap! URL or XML upload' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)
      sample = cart.assignments.find { |a| a.id.start_with?('aa_') }
      expect(sample.body_html).to include('href="https://bjc.edc.org/bjc-r/')
      expect(sample.body_html).to include('Snap!')
      expect(sample.body_html).to include('.xml')
      expect(sample.submission_types).to include('online_text_entry', 'online_upload')
    end
  end

  it 'skips per-page auto-assignments inside skip_topics' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)
      create_task_mod = cart.modules.find { |m| m.title.match?(/Create Task/) }
      autos_inside = create_task_mod.children.flat_map do |c|
        c.children.empty? ? [c] : c.children
      end.select { |c| c.ref&.start_with?('aa_') }
      expect(autos_inside).to be_empty
    end
  end

  it 'writes a QTI assessment file per quiz with a parseable namespace' do
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging)
      cart.quizzes.first(3).each do |quiz_resource|
        path = File.join(staging, quiz_resource.href)
        expect(File.file?(path)).to be(true), path
        doc = Nokogiri::XML(File.read(path)) { |c| c.strict }
        # Default namespace must be the QTI 1.2 ASI namespace.
        expect(doc.root.namespace.href).to eq(CCExport::QtiWriter::QTI_NS)
      end
    end
  end

  it 'auto-quizzes and auto-assignments can be disabled per-config' do
    overrides = { 'auto_quizzes' => { 'enabled' => false }, 'auto_assignments' => { 'enabled' => false } }
    Dir.mktmpdir do |staging|
      cart, = build_csp_cartridge(staging: staging, overrides: overrides)
      expect(cart.quizzes).to be_empty
      auto_assignments = cart.assignments.reject { |a| a.id.start_with?('a_') }
      expect(auto_assignments).to be_empty
    end
  end
end
