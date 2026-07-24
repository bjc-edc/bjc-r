# frozen_string_literal: true

require 'English'
require 'fileutils'

module CCExport
  # Wraps the system `zip` command. We avoid rubyzip so this tool stays free
  # of gem dependencies beyond what the existing build-tools already use.
  module Packager
    module_function

    def write_imscc(staging_dir, output_file)
      FileUtils.mkdir_p(File.dirname(output_file))
      File.delete(output_file) if File.exist?(output_file)

      # `zip -X` strips local extra fields so byte-identical runs over the same
      # input produce byte-identical outputs (subject to mtimes). `-r .` zips
      # the directory contents (not the directory itself) — the manifest must
      # live at the package root.
      output_abs = File.expand_path(output_file)
      Dir.chdir(staging_dir) do
        ok = system('zip', '-q', '-X', '-r', output_abs, '.')
        raise "zip failed (exit #{$CHILD_STATUS&.exitstatus}) for #{output_file}" unless ok
      end
      output_abs
    end
  end
end
