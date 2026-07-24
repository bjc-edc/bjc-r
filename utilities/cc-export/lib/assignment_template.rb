# frozen_string_literal: true

module CCExport
  # Builds the HTML body that goes inside a Canvas `<assignment><description>`
  # element for an auto-generated student-work assignment. We aim for an LMS
  # description that gives the student everything they need without having to
  # flip back and forth: a link to the BJC page, what to submit, and how.
  module AssignmentTemplate
    DEFAULT_INSTRUCTIONS = {
      en: {
        intro: 'Complete the activity on the BJC curriculum page linked below, then submit your work.',
        open_page: 'Open the assignment page',
        submit_heading: 'How to submit',
        submit_url: 'Share your Snap! project and paste the shareable URL in the text-entry box. ' \
                    "(In Snap!, click the menu → File → Share → copy the URL.)",
        submit_xml: 'Or, export your project as XML (File → Save as → Computer) and upload the .xml file.',
        either_ok: 'Either a Snap! share URL or an uploaded .xml file is fine — pick whichever works for your class.'
      },
      es: {
        intro: 'Completa la actividad en la página del curriculum de BJC enlazada abajo y luego entrega tu trabajo.',
        open_page: 'Abrir la página de la tarea',
        submit_heading: 'Cómo entregar',
        submit_url: '¡Comparte tu proyecto de Snap! y pega la URL en el cuadro de texto. ' \
                    "(En Snap!, haz clic en el menú → Archivo → Compartir → copia la URL.)",
        submit_xml: 'O exporta tu proyecto como XML (Archivo → Guardar como → Computadora) y sube el archivo .xml.',
        either_ok: 'Tanto una URL de Snap! como un archivo .xml subido funciona — usa lo que tu clase prefiera.'
      }
    }.freeze

    module_function

    def build(title:, page_url:, language: 'en', extra_html: nil)
      strings = DEFAULT_INSTRUCTIONS[language.to_sym] || DEFAULT_INSTRUCTIONS[:en]

      parts = []
      parts << "<p>#{escape(strings[:intro])}</p>"
      parts << "<p><strong>#{escape(title)}</strong></p>"
      parts << %(<p><a href="#{escape_attr(page_url)}" target="_blank">#{escape(strings[:open_page])} →</a></p>)
      parts << extra_html if extra_html && !extra_html.empty?
      parts << "<h3>#{escape(strings[:submit_heading])}</h3>"
      parts << "<ul>"
      parts << "<li>#{escape(strings[:submit_url])}</li>"
      parts << "<li>#{escape(strings[:submit_xml])}</li>"
      parts << "</ul>"
      parts << "<p><em>#{escape(strings[:either_ok])}</em></p>"
      parts.join("\n")
    end

    def escape(text)
      text.to_s
          .gsub('&', '&amp;')
          .gsub('<', '&lt;')
          .gsub('>', '&gt;')
    end

    def escape_attr(text)
      escape(text).gsub('"', '&quot;').gsub("'", '&#39;')
    end
  end
end
