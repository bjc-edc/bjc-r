# frozen_string_literal: true

# Structural checks on the pages the build tools generate.
#
# The accessibility specs load these pages in a browser, but a browser silently
# repairs broken markup, so it will happily render a page that was never closed
# or that has five stray </body></html> pairs in the middle of it. Both of those
# have shipped before. These checks read the files as text instead, so malformed
# output fails loudly. They need no browser and no network:
#
#   bundle exec rspec utilities/specs/summary_pages_spec.rb

require 'nokogiri'

REPOSITORY_ROOT = File.expand_path('../..', __dir__)

# Where rebuild-all.rb writes, and what it names the pages it writes there.
# Keep in sync with rebuild-all.rb's TO_RUN and the *_file_name methods.
GENERATED_PAGE_GLOBS = [
  'cur/programming/*/unit-*-vocab*.html',
  'cur/programming/*/unit-*-self-check*.html',
  'cur/programming/*/unit-*-exam-reference*.html',
  'cur/programming/atwork*.html',
  'cur/programming/vocab-index*.html',
  'sparks/student-pages/*/unit-*-vocab*.html',
  'sparks/student-pages/vocab-index*.html'
].freeze

# Stale output from an older version of the build tools. Sparks Unit 4 is still
# marked `.todo` on the course page, so rebuild-all.rb doesn't regenerate these.
# TODO: drop this list once Unit 4 ships and the pages are rebuilt.
NOT_REBUILT_YET = ['sparks/student-pages/U4/unit-4-vocab.html'].freeze

found_pages = GENERATED_PAGE_GLOBS
              .flat_map { |glob| Dir.glob(File.join(REPOSITORY_ROOT, glob)) }
              .sort
              .map { |path| path.delete_prefix("#{REPOSITORY_ROOT}/") }
GENERATED_PAGES = (found_pages - NOT_REBUILT_YET).freeze

RSpec.describe 'generated summary pages', type: :generated_pages do
  it 'finds the generated pages to check' do
    expect(GENERATED_PAGES).not_to be_empty
  end

  GENERATED_PAGES.each do |relative_path|
    describe relative_path do
      # Read as UTF-8 explicitly: the curriculum is UTF-8 regardless of the
      # locale this happens to run under.
      subject(:contents) do
        File.read(File.join(REPOSITORY_ROOT, relative_path), encoding: Encoding::UTF_8)
      end

      # Counting tags rather than parsing: every HTML parser worth using
      # recovers from these mistakes, which is exactly why they went unnoticed.
      def tag_count(contents, tag)
        contents.scan(/<#{tag}[\s>]/i).size
      end

      it 'is a single, complete HTML document' do
        expect(tag_count(contents, 'html')).to eq(1)
        expect(tag_count(contents, 'body')).to eq(1)
        expect(contents.scan(%r{</html>}i).size).to eq(1)
        expect(contents.scan(%r{</body>}i).size).to eq(1)
      end

      it 'opens with a doctype and closes at the very end' do
        expect(contents).to start_with('<!DOCTYPE html>')
        expect(contents.rstrip).to end_with('</html>')
      end

      it 'has a non-empty title' do
        expect(Nokogiri::HTML5.parse(contents).title.to_s.strip).not_to be_empty
      end

      it 'loads the llab page runtime' do
        expect(contents).to include('/bjc-r/llab/loader.js')
      end
    end
  end
end
