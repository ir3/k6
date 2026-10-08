# frozen_string_literal: true

require "delegate"
require "zip"
require "tempfile"
require "stringio"

module XlsxReports
  # Axlsx::Packageをラップし、serialize/to_streamの出力(=完成したxlsxのzip)に対して
  # 全シートのpageSetupへblackAndWhite="1"(Excelの「白黒印刷」)を挿入する。
  # caxlsx(4.5.0時点)がblackAndWhiteに対応していないため、生成後のXMLへ直接書き込む。
  # 図形を挿入するShapePatchedPackageなどと重ねて使える(内側のto_streamの結果をそのまま加工する)。
  class BlackAndWhitePatchedPackage < SimpleDelegator
    def initialize(package)
      super(package)
    end

    def serialize(path, *args, **kwargs)
      result = __getobj__.serialize(path, *args, **kwargs)
      patch(path)
      result
    end

    def to_stream(*args, **kwargs)
      Tempfile.create([ "xlsx_bw_patch", ".xlsx" ]) do |tmp|
        tmp.binmode
        tmp.write(__getobj__.to_stream(*args, **kwargs).read)
        tmp.flush
        patch(tmp.path)
        tmp.rewind
        StringIO.new(File.binread(tmp.path))
      end
    end

    private

    def patch(path)
      Zip::File.open(path) do |zip|
        zip.glob("xl/worksheets/sheet*.xml").each do |entry|
          xml = entry.get_input_stream.read
          next unless xml.include?("<pageSetup")

          patched = xml.sub(/<pageSetup([^\/]*)\/>/) { "<pageSetup#{Regexp.last_match(1)} blackAndWhite=\"1\"/>" }
          zip.get_output_stream(entry.name) { |f| f.write(patched) }
        end
      end
    end
  end
end
