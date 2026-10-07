# frozen_string_literal: true

module XlsxReports
  # 行×列の方眼にセルの値・書式・罫線・結合をためておき、最後にまとめてシートへ書き出す。
  # 旧Excel様式のように「このセルにこの値、この範囲を結合、この辺に罫線」と座標で組み立てるための道具。
  # 行・列の番号は1始まり。MitsumoriReport(見積書)などが使う。
  class Grid
    DEFAULT_TEXT_SIZE = 11

    def initialize(rows, cols, font_name: nil)
      @cells = Array.new(rows) { Array.new(cols) { { value: nil, attrs: {} } } }
      @heights = {}
      @merges = []
      @font_name = font_name
    end

    def height(row, points)
      @heights[row] = points
    end

    # row行のcol1〜col2列(rows指定で複数行)に値を置いて結合する。attrsはBaseReport#styleの引数
    def text(row, col1, col2, value, rows: 1, **attrs)
      row2 = row + rows - 1
      @cells[row - 1][col1 - 1][:value] = value
      (row..row2).each do |r|
        (col1..col2).each { |c| @cells[r - 1][c - 1][:attrs].merge!(attrs) }
      end
      @merges << [ row, col1, row2, col2 ] if row2 > row || col2 > col1
    end

    # 範囲の外周に罫線を引く
    def box(row1, col1, row2, col2, kind)
      (col1..col2).each do |c|
        edge(row1, c, :top, kind)
        edge(row2, c, :bottom, kind)
      end
      (row1..row2).each do |r|
        edge(r, col1, :left, kind)
        edge(r, col2, :right, kind)
      end
    end

    # 範囲の片側(:top :bottom :left :right)だけに罫線を引く(下線など)
    def line(row, col1, col2, side, kind = :thin)
      (col1..col2).each { |c| edge(row, c, side, kind) }
    end

    def emit(sheet, report)
      @cells.each_with_index do |cells, idx|
        styles = cells.map do |cell|
          next nil if cell[:attrs].empty?

          attrs = @font_name ? { font_name: @font_name }.merge(cell[:attrs]) : cell[:attrs]
          report.send(:style, sheet, **attrs)
        end
        sheet.add_row(cells.map { |cell| cell[:value] }, style: styles)
        report.send(:set_last_row_height, sheet, @heights[idx + 1] || 15)
      end
      @merges.each do |row1, col1, row2, col2|
        sheet.merge_cells("#{letter(col1)}#{row1}:#{letter(col2)}#{row2}")
      end
    end

    private

    def edge(row, col, side, kind)
      @cells[row - 1][col - 1][:attrs][side] = kind
    end

    def letter(col)
      ("A".ord + col - 1).chr
    end
  end
end
