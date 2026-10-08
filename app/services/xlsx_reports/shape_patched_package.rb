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

    # path(xlsx)のsheet枚目(1始まり)のシートに、drawing_xml(xdr:wsDr)の図形を挿入する。
    # 図形の部品ファイルは drawing(番号).xml。シートごとに別の番号にすること(既定は1枚目・1番)。
    def self.inject_drawing(path, drawing_xml, rel_id: "rIdShapeDrawing", sheet: 1, drawing: 1)
      Zip::File.open(path) do |zip|
        zip.get_output_stream("xl/drawings/drawing#{drawing}.xml") { |f| f.write(drawing_xml) }

        rels_path = "xl/worksheets/_rels/sheet#{sheet}.xml.rels"
        rels_xml = if zip.find_entry(rels_path)
          zip.read(rels_path)
        else
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>'
        end
        rels_xml = rels_xml.sub(
          "</Relationships>",
          %(<Relationship Id="#{rel_id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing#{drawing}.xml"/></Relationships>)
        )
        zip.get_output_stream(rels_path) { |f| f.write(rels_xml) }

        sheet_xml = zip.read("xl/worksheets/sheet#{sheet}.xml").sub("</worksheet>", %(<drawing r:id="#{rel_id}"/></worksheet>))
        zip.get_output_stream("xl/worksheets/sheet#{sheet}.xml") { |f| f.write(sheet_xml) }

        ct_xml = zip.read("[Content_Types].xml")
        unless ct_xml.include?("/xl/drawings/drawing#{drawing}.xml")
          ct_xml = ct_xml.sub(
            "</Types>",
            %(<Override PartName="/xl/drawings/drawing#{drawing}.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/></Types>)
          )
          zip.get_output_stream("[Content_Types].xml") { |f| f.write(ct_xml) }
        end
      end
    end
  end
end
