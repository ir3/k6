# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_07_010000) do
  create_table "adlists", force: :cascade do |t|
    t.string "no"
    t.string "kbn"
    t.string "name"
    t.string "ruby"
    t.integer "gender"
    t.datetime "birthday"
    t.datetime "kbirthday"
    t.string "zip7"
    t.string "address1"
    t.string "address2"
    t.string "address3"
    t.string "tel"
    t.string "fax"
    t.string "mtel"
    t.string "url"
    t.string "company"
    t.string "section"
    t.string "section2"
    t.string "position"
    t.string "cozip7"
    t.string "coad1"
    t.string "coad2"
    t.string "coad3"
    t.string "cotel"
    t.string "comail"
    t.string "cofax"
    t.string "comobile"
    t.string "copok"
    t.string "email"
    t.text "memo"
    t.string "courl"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "keparts", force: :cascade do |t|
    t.string "pcode"
    t.string "form"
    t.string "size"
    t.string "jname"
    t.string "ename"
    t.integer "newprice"
    t.integer "price"
    t.integer "stock"
    t.string "sel_unit"
    t.float "weightkg"
    t.integer "munit"
    t.string "itemno"
    t.string "cordno"
    t.string "comment"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ksystems", force: :cascade do |t|
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_ksystems_on_key", unique: true
  end

  create_table "n_orderparts", force: :cascade do |t|
    t.integer "tvalid"
    t.integer "mno"
    t.integer "sno"
    t.string "partsname"
    t.string "mark"
    t.string "itemno"
    t.string "info"
    t.float "qty"
    t.integer "unitpd"
    t.float "rate"
    t.integer "totala"
    t.float "weight"
    t.string "etc"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mno"], name: "index_n_orderparts_on_mno"
  end

  create_table "order_annotations", force: :cascade do |t|
    t.integer "tvalid"
    t.integer "mno"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mno"], name: "index_order_annotations_on_mno"
  end

  create_table "order_logs", force: :cascade do |t|
    t.integer "tvalid"
    t.integer "mno"
    t.date "datelog"
    t.integer "kubun"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mno", "kubun"], name: "index_order_logs_on_mno_and_kubun"
  end

  create_table "orderparts", force: :cascade do |t|
    t.integer "mno"
    t.integer "sno"
    t.string "itemno"
    t.string "cordno"
    t.string "kzaiko"
    t.string "partno"
    t.string "info"
    t.integer "qty"
    t.integer "bqty"
    t.string "unit"
    t.integer "unitpd"
    t.integer "unitpi"
    t.integer "unitpi2"
    t.float "irate"
    t.integer "totala"
    t.integer "total2"
    t.date "ndate"
    t.float "unitweight"
    t.float "totalweight"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer "tvalid"
    t.integer "mno"
    t.string "st"
    t.integer "adlist_id"
    t.date "rdate"
    t.string "ncomment"
    t.string "ndate"
    t.string "nplase"
    t.string "ldate"
    t.string "tcondition"
    t.string "etype"
    t.string "engno"
    t.string "shipname"
    t.string "country"
    t.integer "pnum"
    t.string "inspection"
    t.string "hno"
    t.string "orderitem"
    t.string "memo"
    t.string "tname"
    t.string "idate"
    t.string "odate"
    t.string "mdate"
    t.float "irate"
    t.integer "nebiki"
    t.float "irate2"
    t.string "tc"
    t.string "tcno"
    t.string "zp"
    t.string "zpno"
    t.string "glc"
    t.string "glcno"
    t.string "mg"
    t.string "mgno"
    t.string "ono"
    t.date "mitday"
    t.date "syuday"
    t.date "seiday"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tax_rate"
  end

  create_table "parts", force: :cascade do |t|
    t.string "pcode"
    t.string "form"
    t.string "jname"
    t.string "ename"
    t.string "stock"
    t.string "sel_unit"
    t.integer "price"
    t.integer "newprice"
    t.float "weightkg"
    t.integer "munit"
    t.string "itemno"
    t.string "cordno"
    t.string "comment"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "registries", force: :cascade do |t|
    t.string "countryid"
    t.string "country"
    t.float "rate"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stock_settings", force: :cascade do |t|
    t.string "partno", null: false
    t.integer "snum"
    t.integer "znum"
    t.string "opartno"
    t.string "memo"
    t.integer "nonview"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["partno"], name: "index_stock_settings_on_partno", unique: true
  end

  create_table "stockbs", force: :cascade do |t|
    t.string "partno"
    t.integer "kind"
    t.date "indate"
    t.integer "num"
    t.integer "inprice"
    t.integer "irprice"
    t.integer "invalue"
    t.integer "irvalue"
    t.date "outdate"
    t.integer "onum"
    t.integer "mno"
    t.integer "orprice"
    t.integer "orvalue"
    t.string "itemno"
    t.string "cordno"
    t.string "memo"
    t.string "cname"
    t.string "sname"
    t.integer "novalid"
    t.integer "ikubun"
    t.integer "okubun"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_stockbs_on_id"
  end

  create_table "stocks", force: :cascade do |t|
    t.string "partno"
    t.integer "kind"
    t.date "indate"
    t.integer "num"
    t.integer "inprice"
    t.integer "irprice"
    t.integer "invalue"
    t.integer "irvalue"
    t.date "outdate"
    t.integer "onum"
    t.integer "mno"
    t.integer "orprice"
    t.integer "orvalue"
    t.string "itemno"
    t.string "cordno"
    t.string "memo"
    t.string "cname"
    t.string "sname"
    t.integer "novalid"
    t.integer "ikubun"
    t.integer "okubun"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_stocks_on_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.boolean "done"
    t.string "name"
    t.text "notes"
    t.integer "priority"
    t.date "due"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_profiles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "firstname"
    t.string "lastname"
    t.integer "state"
    t.datetime "sign_in_at"
    t.datetime "sign_out_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_profiles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "sessions", "users"
  add_foreign_key "user_profiles", "users"
end
