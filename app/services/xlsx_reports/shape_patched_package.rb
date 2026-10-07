# frozen_string_literal: true

require "delegate"
require "zip"
require "tempfile"
require "stringio"

module XlsxReports
  # Axlsx::Packageをラップし、serialize/to_streamの出力(=完成したxlsxのzip)に図形を挿入する。
  # caxlsxには図形のAPIが無いため、生成済みのxlsxの1枚目へ、図形(drawing)のXMLを後から書き込む。
  # SeikyuReportのBracketShapePatchedPackageと同じ手法。
  class ShapePatchedPackage < SimpleDelegator
    def initialize(package, patcher)
      super(package)
      @patcher = patcher
    end

    def serialize(path, *args, **kwargs)
      result = __getobj__.serialize(path, *args, **kwargs)
      @patcher.call(path)
      result
    end

    def to_stream(*args, **kwargs)
      Tempfile.create([ "xlsx_shape_patch", ".xlsx" ]) do |tmp|
        tmp.binmode
        tmp.write(__getobj__.to_stream(*args, **kwargs).read)
        tmp.flush
        @patcher.call(tmp.path)
        tmp.rewind
        StringIO.new(File.binread(tmp.path))
      end
    end

    # path(xlsx)の1枚目のシートに、drawing_xml(xdr:wsDr)の図形を挿入する。
    def self.inject_drawing(path, drawing_xml, rel_id: "rIdShapeDrawing")
      Zip::File.open(path) do |zip|
        zip.get_output_stream("xl/drawings/drawing1.xml") { |f| f.write(drawing_xml) }

        rels_path = "xl/worksheets/_rels/sheet1.xml.rels"
        rels_xml = if zip.find_entry(rels_path)
          zip.read(rels_path)
        else
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>'
        end
        rels_xml = rels_xml.sub(
          "</Relationships>",
          %(<Relationship Id="#{rel_id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/></Relationships>)
        )
        zip.get_output_stream(rels_path) { |f| f.write(rels_xml) }

        sheet_xml = zip.read("xl/worksheets/sheet1.xml").sub("</worksheet>", %(<drawing r:id="#{rel_id}"/></worksheet>))
        zip.get_output_stream("xl/worksheets/sheet1.xml") { |f| f.write(sheet_xml) }

        ct_xml = zip.read("[Content_Types].xml")
        unless ct_xml.include?("/xl/drawings/drawing1.xml")
          ct_xml = ct_xml.sub(
            "</Types>",
            %(<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>)
          )
          zip.get_output_stream("[Content_Types].xml") { |f| f.write(ct_xml) }
        end
      end
    end
  end
end
