# frozen_string_literal: true

class OrdersController < ApplicationController
  # 掛け率は数字と小数点だけ（"0x1A" や "1e3" のような Ruby が数値と解釈する書き方は通さない）
  RATE_FORMAT = /\A\d+(\.\d+)?\z/

  before_action :require_authentication

  # GET /orders
  # GET /orders.json
  def index
    @shipname = params[:shipname]
    @engno    = params[:engno]
    @keyword  = params[:keyword]
    @keykind  = params[:keykind]
    logger.debug  @keyword
    logger.debug  @keykind
    mno_order = resolve_mno_order
    ym = Time.now.strftime('%Y%m')
    session[:keyword] = nil
    session[:keykind] = nil
    session[:shipname] = nil
    session[:engno] = nil
    if @keyword && !@keyword.empty?
      session[:keyword] = @keyword.to_s
      logger.debug session[:keyword]
      if (@keyword == 'next') || (@keyword == 'last') || (@keyword == 'now')
        if session[:yearmonth] && !session[:yearmonth].empty? && @keyword != 'now'
          ym = session[:yearmonth]
        end
        date = Date.parse(ym + '01')
        if @keyword == 'next'
          ym = date.next_month.strftime('%Y%m')
        elsif @keyword == 'last'
          ym = date.last_month.strftime('%Y%m')
        end
        @orders = Order.joins(:adlists).find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND mno like '#{ym}%' ORDER BY id #{mno_order}")
        @search_condition = "対象年月: #{ym}"
      elsif @keykind == 'companyid'
        session[:keykind] = @keykind.to_s
        @orders = Order.where('adlist_id = ?', @keyword).order("id #{mno_order}")
        @search_condition = "取引先ID: #{@keyword}"
      else
        @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND mno like'%#{@keyword}%' ORDER BY id #{mno_order}")
        @search_condition = "取引No.: #{@keyword}"
      end
    elsif @shipname && !@shipname.empty?
      session[:shipname] = @shipname.to_s
      @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND shipname like'#{@shipname}%' ORDER BY id #{mno_order}")
      @search_condition = "船名: #{@shipname}"
    elsif @engno && !@engno.empty?
      session[:engno] = @engno.to_s
      @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND engno like'#{@engno}%' ORDER BY id #{mno_order}")
      @search_condition = "機番: #{@engno}"
    else
      ym = session[:yearmonth] if session[:yearmonth]
      @orders = Order.joins(:adlists).find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND mno like '#{ym}%' ORDER BY id #{mno_order}")
      @search_condition = "対象年月: #{ym}"
    end
    session[:yearmonth] = ym
    @orders = paginate_orders(@orders)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @orders }
    end
  end

  # GET/POST /orders/alllist
  def alllist
    if request.post?
      redirect_to orders_alllist_path(smno: params[:SMNo], fixed: params[:fixed])
      return
    end

    smno  = params[:smno].to_s
    smno  = session[:smno].to_s if smno.empty?
    session[:smno] = smno unless smno.empty?

    fixed = params[:fixed].to_i
    label = fixed == 1 ? "受注決定分" : "未受決分"

    base = Order.where("deleted_at IS NULL")
                .where("CAST(mno AS TEXT) LIKE ?", "#{smno}%")
                .order(:mno)

    @orders = if fixed == 1
      base.where("orderitem LIKE ?", "%（受注）%")
    else
      base.where("orderitem NOT LIKE ? OR orderitem IS NULL", "%（受注）%")
    end
    @orders = paginate_orders(@orders)
    @title = "#{smno} #{label}"
    @search_condition = @title
  end

  # GET/POST /orders/search
  def search
    # TurboはPOSTフォームの応答にリダイレクトを要求するため、
    # POST時はGETへリダイレクトしてから描画する(Post/Redirect/Getパターン)。
    if request.post?
      redirect_to orders_search_path(keyword: params[:keyword], keykind: params[:keykind])
      return
    end

    keyword = params[:keyword]
    keykind = params[:keykind]
    logger.debug  keyword
    logger.debug  keykind

    # 取引No.(9桁)がそのまま一致する場合は、取引台帳を経由せず注文部品詳細へ直行する
    if keykind.blank? && keyword.to_s.match?(/\A\d{9}\z/)
      order = Order.find_by(mno: keyword)
      return redirect_to(order_path(order)) if order
    end

    mno_order = resolve_mno_order
    keykind_labels = { "etype" => "形式検索", "engno" => "機番検索", "shipname" => "船名検索", "company" => "会社名検索", "memo" => "メモ検索" }
    if keykind && !keykind.empty?
      if keykind == 'company'
        adlist_id = Adlist.find_by_sql("SELECT * FROM adlists WHERE (deleted_at IS NULL) AND #{keykind} like '%#{keyword}%'").first
        @orders = Order.where('adlist_id = ?', adlist_id.id).order("id #{mno_order}")
      else
        @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND #{keykind} like '%#{keyword}%' ORDER BY id #{mno_order}")
      end
      @search_condition = "#{keykind_labels[keykind] || keykind}: #{keyword}"
    elsif
      session[:yearmonth] = keyword
      @orders = Order.find_by_sql("SELECT * FROM orders WHERE (deleted_at IS NULL) AND mno like '#{keyword}%' ORDER BY id #{mno_order}")
      @search_condition = "取引No.: #{keyword}"
    end
    @orders = paginate_orders(@orders)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @parts }
      format.json { render json: @parts }
    end
  end

  # POST /orders/copy
  def copy
    @ori   = Order.find(session[:order_id])
    mno = next_mno_for_copy(order_path(@ori)) or return

    @order = Order.new
    @order.mno        = mno
    @order.st         = @ori.st
    @order.adlist_id  = @ori.adlist_id
    @order.rdate      = nil
    @order.ncomment   = @ori.ncomment
    @order.ndate      = @ori.ndate
    @order.nplase     = @ori.nplase
    @order.ldate      = @ori.ldate
    @order.tcondition = @ori.tcondition
    @order.etype      = @ori.etype
    @order.engno      = @ori.engno
    @order.shipname   = @ori.shipname
    @order.country    = @ori.country
    @order.pnum       = @ori.pnum
    @order.inspection = @ori.inspection
    @order.hno        = @ori.hno
    @order.orderitem  = mno.to_s[4, 5]
    @order.memo       = nil
    @order.tname      = @ori.tname
    @order.idate      = @ori.idate
    @order.odate      = @ori.odate
    @order.mdate      = @ori.mdate
    @order.irate      = @ori.irate
    @order.nebiki     = @ori.nebiki
    @order.irate2     = @ori.irate2
    @order.tc         = @ori.tc
    @order.tcno       = @ori.tcno
    @order.zp         = @ori.zp
    @order.zpno       = @ori.zpno
    @order.glc        = @ori.glc
    @order.glcno      = @ori.glcno
    @order.mg         = @ori.mg
    @order.mgno       = @ori.mgno
    @order.ono        = @ori.ono
    @order.mitday     = @ori.mitday
    @order.syuday     = @ori.syuday
    @order.mitday     = @ori.mitday
    @order.seiday     = @ori.seiday

    @order.save
    # 部品詳細も複製
    oriparts = Orderpart.find_by_sql("SELECT * FROM orderparts WHERE mno=#{@ori.mno}")
    oriparts.each do |oripart|
      orderpart = Orderpart.new
      orderpart.mno    = @order.mno
      orderpart.sno    = oripart.sno
      orderpart.itemno = oripart.itemno
      orderpart.cordno = oripart.cordno
      orderpart.partno = oripart.partno
      orderpart.info   = oripart.info
      orderpart.qty    = oripart.qty
      orderpart.unitpd = oripart.unitpd
      orderpart.unitpi = oripart.unitpi
      orderpart.unitpi2 = oripart.unitpi2
      orderpart.irate  = oripart.irate
      orderpart.totala = oripart.totala
      orderpart.total2 = oripart.total2
      orderpart.ndate  = oripart.ndate
      orderpart.unitweight = oripart.unitweight
      orderpart.totalweight = oripart.totalweight
      orderpart.save
    end

    redirect_to "/orders/#{@order.id}"
  end

  # POST /orders/keycopy
  def keycopy
    @ori   = Order.find(session[:order_id])
    mno = next_mno_for_copy(order_path(@ori)) or return

    @order = Order.new
    @order.mno        = mno
    @order.st         = @ori.st
    @order.adlist_id  = @ori.adlist_id
    @order.rdate      = nil
    @order.ncomment   = @ori.ncomment
    @order.ndate      = @ori.ndate
    @order.nplase     = @ori.nplase
    @order.ldate      = @ori.ldate
    @order.tcondition = @ori.tcondition
    @order.etype      = @ori.etype
    @order.engno      = @ori.engno
    @order.shipname   = @ori.shipname
    @order.country    = @ori.country
    @order.pnum       = nil
    @order.inspection = @ori.inspection
    @order.hno        = @ori.hno
    @order.orderitem  = mno.to_s[4, 5]
    @order.memo       = nil
    @order.tname      = @ori.tname
    @order.idate      = @ori.idate
    @order.odate      = @ori.odate
    @order.mdate      = @ori.mdate
    @order.irate      = @ori.irate
    @order.nebiki     = @ori.nebiki
    @order.irate2     = @ori.irate2
    @order.tc         = @ori.tc
    @order.tcno       = @ori.tcno
    @order.zp         = @ori.zp
    @order.zpno       = @ori.zpno
    @order.glc        = @ori.glc
    @order.glcno      = @ori.glcno
    @order.mg         = @ori.mg
    @order.mgno       = @ori.mgno
    @order.ono        = @ori.ono
    @order.mitday     = @ori.mitday
    @order.syuday     = @ori.syuday
    @order.mitday     = @ori.mitday
    @order.seiday     = @ori.seiday

    @order.save
    redirect_to "/orders/#{@order.id}"
  end

  # POST /orders/ocopy
  def ocopy
    adlist_id = params[:adlist_id]
    mno = next_mno_for_copy(orders_path) or return

    @order = Order.new
    @order.mno        = mno
    @order.adlist_id  = adlist_id

    @order.save
    redirect_to "/orders/#{@order.id}/edit"
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
    @order = Order.find(params[:id])
    session[:order_id] = @order.id
    session[:mno] = @order.mno
    # @orderparts = Orderpart.find_by_sql("SELECT * FROM orderparts WHERE (deleted_at IS NULL) AND mno=#{@order.mno}")
    # 各グループの中を「順(SNo)」順(同じ順は作成順＝古いものが上)で表示する。順が空の行は 0 として扱う
    # （並び替え後表示 OrderSortedItems と同じ）。Orderpartのdefault_scopeはid DESC(新しいものが上)なのでreorderで上書きする。
    # A部品・B部品・部品番号不明のグループ分けは、画面側でこの並びのまま行う
    @orderparts = Orderpart.where(mno: @order.mno).reorder(Arel.sql("COALESCE(sno, 0)"), :id)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @order }
    end
  end

  # POST /orders/1/add_part
  # 注文部品詳細の「部品番号を入力して部品選択」。部品番号で部品明細を追加し、注文部品詳細へ戻る。
  def add_part
    @order = Order.find(params[:id])
    result = OrderPartAdder.new(@order, params[:partsno]).call

    if result.success?
      flash[:notice] = added_part_message(result)
      flash[:warning] = result.warnings.join(" ") if result.warnings.any?
    else
      flash[:alert] = result.error
    end
    redirect_to @order
  end

  # POST /orders/1/add_part_name
  # 注文部品詳細の「部品番号が不明な分を部品名入力」。部品名だけで部品番号なしの明細を仮登録する。
  def add_part_name
    @order = Order.find(params[:id])
    result = OrderPartNameAdder.new(@order, params[:partsname]).call

    if result.success?
      flash[:notice] = "部品名「#{result.row.partsname}」を部品番号なしで追加しました。"
    else
      flash[:alert] = result.error
    end
    redirect_to @order
  end

  # GET /orders/1/sorted
  # 並び替え後表示画面。注文部品詳細で「並び替え」した後に遷移してくる想定の画面で、
  # ここから請求書・納品書などの帳票出力ボタンを呼び出す。
  # (「並び替え」自体の処理は別途 注文部品詳細 側に実装予定のため、現時点では並び替え済みの
  #  Orderpart一覧をそのまま表示する)
  # 明細はOrderpart(部品番号あり)とNOrderpart(部品番号無)を「順(SNo)」で一本化したものを使う。
  # 帳票出力(JuchuMemoReport等)も同じOrderSortedItemsを参照するため、この画面と帳票の
  # 明細内容・並び順は常に一致する。
  def sorted
    @order = Order.find(params[:id])
    @adlist = Adlist.find_by(no: @order.adlist_id.to_s)
    @items = OrderSortedItems.for(@order)
  end

  # GET /orders/1/report/:kind
  def report
    @order = Order.find(params[:id])
    entry = XlsxReports::Registry[params[:kind]]

    if entry.nil?
      redirect_to sorted_order_path(@order), alert: "不明な帳票種別です"
      return
    end

    klass = entry[:klass]&.safe_constantize
    if klass.nil?
      redirect_to sorted_order_path(@order), alert: "「#{entry[:label]}」はまだ未実装です"
      return
    end

    report = klass.new(@order)
    package = report.generate
    send_data package.to_stream.read, filename: report.filename, type: Mime[:xlsx], disposition: "attachment"
  end

  # GET /orders/new
  # GET /orders/new.json
  # 取引台帳追加（新規取引登録）。管理番号は表示だけで、登録の瞬間に採番し直す(create)。
  def new
    @order = Order.new(rdate: Date.current)
    @order.mno = Order.next_mno
    @order.orderitem = default_orderitem(@order.mno)

    respond_to do |format|
      format.html # new.html.haml
      format.json { render json: @order }
    end
  end

  # GET /orders/1/edit
  def edit
    @order = Order.find(params[:id])
    @orderparts = Orderpart.where(mno: @order.mno).reorder(:sno)
  end

  # POST /orders
  # POST /orders.json
  # 管理番号は画面からは受け取らず、ここで採番する（orderin.asp 相当。採番は Order.next_mno）。
  def create
    @order = Order.new(order_params)

    problems = new_order_problems
    if problems.empty?
      # 取引先と機番だけの入力でも登録できるよう、空欄は同じ機番の直近の注文から埋める。
      @source_order = @order.fill_blanks_from_latest_by_engno
      @order.country = Registry.country_names.first if @order.country.blank?
    end
    Order::NEW_ORDER_DEFAULTS.each { |attr, value| @order[attr] = value if @order[attr].nil? }
    saved = problems.empty? && save_with_new_mno(problems)

    respond_to do |format|
      if saved
        format.html { redirect_to @order, notice: created_message }
        format.json { render json: @order, status: :created, location: @order }
      else
        problems.each { |message| @order.errors.add(:base, message) }
        # Turbo は 4xx でないとフォーム送信の応答を描画しないので 422 にする
        format.html { render action: "new", status: :unprocessable_entity }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /orders/1
  # PUT /orders/1.json
  # 取引台帳修正画面のほか、注文部品詳細の掛け率・値引き・消費税率の行からも呼ばれる
  # （それらは日付や取引先を送らないので、order_edit_problems では対象外になる）。
  def update
    @order = Order.find(params[:id])
    return reject_invalid_rates unless valid_rate_params?

    attrs = order_params
    adlist_changed = attrs[:adlist_id].present? && attrs[:adlist_id].to_i != @order.adlist_id
    @order.assign_attributes(attrs)
    problems = order_edit_problems(adlist_changed)

    respond_to do |format|
      if problems.empty? && @order.save
        format.html { redirect_to @order, notice: "取引台帳を修正しました。" }
        format.json { head :no_content }
      else
        problems.each { |message| @order.errors.add(:base, message) }
        # Turbo は 4xx でないとフォーム送信の応答を描画しないので 422 にする
        format.html { render action: "edit", status: :unprocessable_entity }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order = Order.find(params[:id])
    @order.delete_with_parts!

    respond_to do |format|
      # DELETE のリダイレクトは 303 にする（302 だと Turbo/fetch が DELETE のまま追従してしまう）
      format.html { redirect_to orders_url, status: :see_other, notice: "取引 #{@order.mno} を削除しました。" }
      format.json { head :no_content }
    end
  end

  private

  # 取引No.の並び順(ASC/DESC)。取引台帳の表示は新しい取引が上に来る降順を初期値にする。
  # 見出しの「取引No↕」(mno_order パラメータ付き)を押すたびに昇降を切り替え、
  # パラメータなしで開き直すと降順に戻る。
  def resolve_mno_order
    current = session[:mno_order] == "ASC" ? "ASC" : "DESC"
    session[:mno_order] =
      if params[:mno_order]
        current == "DESC" ? "ASC" : "DESC"
      else
        "DESC"
      end
  end

  # find_by_sql の結果（配列）と ActiveRecord::Relation のどちらでもページネーションできるようにする
  def paginate_orders(orders)
    if orders.is_a?(ActiveRecord::Relation)
      orders.page(params[:page])
    else
      Kaminari.paginate_array(orders).page(params[:page])
    end
  end

  # 複製(copy / keycopy / ocopy)で使う新しい取引管理No.を採番して返す。
  # 全体の最大+1 だった古い newmno は、異常な番号(405024078)があると 405024079 を発番してしまうため、
  # 取引台帳追加と同じ Order.next_mno（今月の範囲だけで最大+1）に揃えた。
  # 今月の連番が上限に達して採番できない時は、複製せずに戻して nil を返す。
  def next_mno_for_copy(back_to)
    mno = Order.next_mno
    return mno if mno

    redirect_to back_to, alert: "今月の管理番号が上限(#{Order::MNO_SEQ_MAX})に達したため、複製できません。"
    nil
  end

  def order_params
    params.require(:order).permit(:adlist_id, :shipname, :engno, :orderitem, :memo, :ono, :etype,
                                  :country, :tc, :tcno, :zp, :zpno, :glc, :glcno, :mg,
                                  :mgno, :rdate, :ncomment, :irate, :irate2, :nebiki, :tax_rate)
  end

  # 画面から来た値のうち、モデルでは弾かれない（または別の値に化ける）ものを保存前に確認する。
  # adlist_changed は取引先が変更された時だけ true（変更なしなら既存データの不整合を理由に止めない）。
  def order_edit_problems(adlist_changed)
    problems = []
    if adlist_changed && !Adlist.exists?(no: @order.adlist_id.to_s)
      problems << "選択された取引先が見つかりません。取引先を選び直してください。"
    end
    problems << "納入期日が正しい日付ではありません。" unless valid_rdate_params?
    problems
  end

  # date_select は2月31日のような日付も選べてしまい、そのまま保存すると nil になって納入期日が消える。
  # 日付を送っていない更新（値引き・消費税率の行など）は対象外。
  def valid_rdate_params?
    parts = %w[1i 2i 3i].map { |i| params.dig(:order, "rdate(#{i})").to_s }
    return true if parts.any?(&:blank?)

    Date.valid_date?(*parts.map(&:to_i))
  end

  # 新規登録の件名の既定値は管理番号の下5桁（複製の ocopy や実データの件名「10012（受注）」と同じ形）
  def default_orderitem(mno)
    mno&.to_s&.slice(4, 5)
  end

  # 新規登録の入力を保存前に確認する。取引先は必須（実データでは取引先なしの注文は0件）。
  def new_order_problems
    problems = []
    if @order.adlist_id.blank?
      problems << "取引先を選択してください。"
    elsif !Adlist.exists?(no: @order.adlist_id.to_s)
      problems << "選択された取引先が見つかりません。取引先を選び直してください。"
    end
    problems << "納入期日が正しい日付ではありません。" unless valid_rdate_params?
    problems
  end

  # 登録の瞬間に管理番号を採番して保存する。保存できなければ false を返し、理由を problems に足す。
  # 画面に表示した番号(expected_mno)と採番結果が違えば、登録せずに新しい番号を見せて確認してもらう。
  def save_with_new_mno(problems)
    Order.transaction do
      mno = Order.next_mno
      if mno.nil?
        problems << "今月の管理番号が上限(#{Order::MNO_SEQ_MAX})に達したため登録できません。"
        raise ActiveRecord::Rollback
      end

      expected = params[:expected_mno].presence
      if expected && expected.to_i != mno
        problems << "ほかの方が先に登録したため、管理番号が #{expected} から #{mno} に変わりました。内容を確認して、もう一度登録してください。"
        @order.mno = mno
        raise ActiveRecord::Rollback
      end

      @order.mno = mno
      @order.orderitem = default_orderitem(mno) if @order.orderitem.blank?
      @order.save!
    end
    problems.empty?
  end

  # 登録完了のメッセージ。同じ機番の直近の注文で空欄を埋めたときは、その取引Noも知らせる
  def created_message
    message = "取引台帳を登録しました。管理番号 #{@order.mno}"
    message += "（機番 #{@order.engno.to_s.strip} の直近の取引 #{@source_order.mno} の情報で空欄を補いました）" if @source_order
    message
  end

  def added_part_message(result)
    message = "部品 #{result.partno} を追加しました。"
    message += "（在庫台帳にあるため、在庫分と通常の#{result.rows.size}行）" if result.rows.size > 1
    message
  end

  # 掛け率は「0以上の数値」だけ受け付ける（空欄は未設定として許可）。
  # 掛け率を送っていない更新（取引台帳修正画面など）は対象外。
  def valid_rate_params?
    %w[irate irate2].all? do |key|
      value = params.dig(:order, key).to_s.strip
      value.empty? || value.match?(RATE_FORMAT)
    end
  end

  # 掛け率は注文部品詳細の入力欄から送られてくるので、エラーはそちらへ戻して表示する
  def reject_invalid_rates
    message = "掛け率は0以上の数値（例: 0.85）で入力してください。"
    respond_to do |format|
      format.html { redirect_to @order, alert: message }
      format.json { render json: { error: message }, status: :unprocessable_entity }
    end
  end
end
