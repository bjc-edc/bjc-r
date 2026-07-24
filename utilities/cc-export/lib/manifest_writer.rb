# frozen_string_literal: true

require 'fileutils'
require 'nokogiri'

require_relative 'cartridge'
require_relative 'qti_writer'

module CCExport
  # Serializes a Cartridge into the XML files inside an IMS Common Cartridge
  # 1.3 package: the manifest, one XML per web link, and one XML per assignment
  # (Canvas extension namespace — other LMSes ignore it and fall back to the
  # underlying resource).
  #
  # CC 1.3 spec: https://www.imsglobal.org/cc/ccv1p3/imscc_profilev1p3-Implementation.html
  module ManifestWriter
    MANIFEST_NS = 'http://www.imsglobal.org/xsd/imsccv1p3/imscp_v1p1'
    LOM_RES_NS  = 'http://ltsc.ieee.org/xsd/imsccv1p3/LOM/resource'
    LOMIMSCC_NS = 'http://ltsc.ieee.org/xsd/imsccv1p3/LOM/manifest'
    XSI_NS      = 'http://www.w3.org/2001/XMLSchema-instance'

    WEBLINK_NS         = 'http://www.imsglobal.org/xsd/imsccv1p3/imswl_v1p3'
    WEBLINK_RES_TYPE   = 'imswl_xmlv1p3'
    WEBCONTENT_TYPE    = 'webcontent'
    CANVAS_ASSIGN_TYPE = 'assignment_xmlv1p0'
    CANVAS_NS          = 'http://canvas.instructure.com/xsd/cccv1p0'

    SCHEMA_LOCATION = [
      "#{MANIFEST_NS} http://www.imsglobal.org/profile/cc/ccv1p3/ccv1p3_imscp_v1p2_v1p0.xsd",
      "#{LOM_RES_NS} http://www.imsglobal.org/profile/cc/ccv1p3/LOM/ccv1p3_lomresource_v1p0.xsd",
      "#{LOMIMSCC_NS} http://www.imsglobal.org/profile/cc/ccv1p3/LOM/ccv1p3_lommanifest_v1p0.xsd"
    ].join(' ')

    module_function

    def build_manifest(cart)
      doc = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.manifest(
          identifier: cart.identifier,
          xmlns: MANIFEST_NS,
          'xmlns:lom' => LOM_RES_NS,
          'xmlns:lomimscc' => LOMIMSCC_NS,
          'xmlns:xsi' => XSI_NS,
          'xsi:schemaLocation' => SCHEMA_LOCATION
        ) do
          xml.metadata do
            xml.schema 'IMS Common Cartridge'
            xml.schemaversion '1.3.0'
            xml['lomimscc'].lom do
              xml['lomimscc'].general do
                xml['lomimscc'].title do
                  xml['lomimscc'].string cart.title
                end
                unless cart.description.to_s.empty?
                  xml['lomimscc'].description do
                    xml['lomimscc'].string cart.description
                  end
                end
                xml['lomimscc'].language cart.language
              end
            end
          end

          xml.organizations do
            xml.organization(
              identifier: "org_#{cart.identifier}",
              structure: 'rooted-hierarchy'
            ) do
              xml.item(identifier: "root_#{cart.identifier}") do
                cart.modules.each { |mod| emit_org_item(xml, mod) }
              end
            end
          end

          xml.resources do
            cart.weblinks.each do |wl|
              href = "weblinks/#{wl.id}.xml"
              xml.resource(identifier: wl.id, type: WEBLINK_RES_TYPE, href: href) do
                xml.file(href: href)
              end
            end
            cart.webcontents.each do |wc|
              xml.resource(identifier: wc.id, type: WEBCONTENT_TYPE, href: wc.href) do
                xml.file(href: wc.href)
                wc.extra_files.each { |f| xml.file(href: f) }
              end
            end
            cart.assignments.each do |a|
              href = assignment_settings_path(a)
              xml.resource(identifier: a.id, type: CANVAS_ASSIGN_TYPE, href: href) do
                xml.file(href: href)
              end
            end
            cart.quizzes.each do |q|
              xml.resource(identifier: q.id, type: QtiWriter::QTI_RESOURCE_TYPE, href: q.href) do
                xml.file(href: q.href)
              end
            end
          end
        end
      end
      doc.to_xml
    end

    def write_quiz(staging_dir, quiz_resource)
      xml_str = QtiWriter.build_assessment_xml(quiz_resource.quiz)
      path = File.join(staging_dir, quiz_resource.href)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, xml_str)
      path
    end

    def write_weblink(staging_dir, weblink)
      doc = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.webLink(
          xmlns: WEBLINK_NS,
          'xmlns:xsi' => XSI_NS,
          'xsi:schemaLocation' =>
            "#{WEBLINK_NS} http://www.imsglobal.org/profile/cc/ccv1p3/ccv1p3_imswl_v1p3.xsd"
        ) do
          xml.title weblink.title
          xml.url(href: weblink.url, target: weblink.target)
        end
      end
      path = File.join(staging_dir, 'weblinks', "#{weblink.id}.xml")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, doc.to_xml)
      path
    end

    def write_assignment(staging_dir, assignment)
      doc = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.assignment(
          identifier: assignment.id,
          xmlns: CANVAS_NS,
          'xmlns:xsi' => XSI_NS
        ) do
          xml.title assignment.title
          # Wrap the body in CDATA so the LMS receives the HTML markup
          # untransformed (instead of seeing literal `&lt;p&gt;` text).
          xml.description { xml.cdata(assignment.body_html.to_s) }
          xml.points_possible format('%.1f', assignment.points)
          xml.grading_type 'points'
          xml.submission_types(
            (assignment.submission_types.empty? ? ['none'] : assignment.submission_types).join(',')
          )
          xml.workflow_state 'published'
        end
      end
      path = File.join(staging_dir, assignment_settings_path(assignment))
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, doc.to_xml)
      path
    end

    def assignment_settings_path(assignment)
      "#{assignment.id}/assignment_settings.xml"
    end

    def emit_org_item(xml, item)
      attrs = { identifier: item.id }
      attrs[:identifierref] = item.ref if item.ref
      xml.item(**attrs) do
        xml.title item.title
        item.children.each { |child| emit_org_item(xml, child) }
      end
    end
  end
end
