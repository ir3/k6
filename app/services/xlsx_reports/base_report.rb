# frozen_string_literal: true

require "caxlsx"

module XlsxReports
  # 帳票xlsx生成の共通基盤。
  # サブクラスは #build(workbook) と #filename を実装する。
  class BaseReport
    def generate
      package = Axlsx::Package.new
      @style_cache = {}
      build(package.workbook)
      package
    end

    def filename
      "report.xlsx"
    end

    private

    def build(_workbook)
      raise NotImplementedError, "#{self.class} must implement #build(workbook)"
    end

    # セル単位で辺ごとに罫線スタイルを指定できるスタイルヘルパー。
    # border: に指定した種類が四辺の初期値になり、top:/bottom:/left:/right: で個別に上書きできる。
    # (例: border: :thin, bottom: :double で「全辺thin・下だけdouble」)
    # 同じ組み合わせは1つのstyleにキャッシュして再利用する。
    def style(sheet, border: nil, top: nil, bottom: nil, left: nil, right: nil,
              bold: false, size: 11, halign: nil, valign: nil,
              fill: nil, number_format: nil, font_name: "MS PGothic")
      edges = { top: top || border, bottom: bottom || border, left: left || border, right: right || border }
      border_opts = edges.filter_map { |edge, edge_style| { style: edge_style, color: "FF000000", edges: [ edge ] } if edge_style }

      key = [ edges, bold, size, halign, valign, fill, number_format, font_name ]
      cache = (@style_cache[sheet.object_id] ||= {})
      cache[key] ||= sheet.styles.add_style(
        {
          fn: font_name,
          b: bold,
          sz: size,
          alignment: { horizontal: halign, vertical: valign },
          format_code: number_format,
          border: border_opts.presence,
          bg_color: fill
        }.compact
      )
    end

    # axlsxの仕様上、列幅は行を追加した後に設定しないと自動フィット幅で上書きされる。
    # そのためbuild内では明細行を追加し終えた最後にこれを呼ぶこと。
    def set_column_widths(sheet, *widths)
      sheet.column_widths(*widths)
    end
  end
end
