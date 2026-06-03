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

ActiveRecord::Schema[8.1].define(version: 2026_06_03_011248) do
  create_table "adlists", force: :cascade do |t|
    t.string "address1"
    t.string "address2"
    t.string "address3"
    t.datetime "birthday"
    t.string "coad1"
    t.string "coad2"
    t.string "coad3"
    t.string "cofax"
    t.string "comail"
    t.string "comobile"
    t.string "company"
    t.string "copok"
    t.string "cotel"
    t.string "courl"
    t.string "cozip7"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email"
    t.string "fax"
    t.integer "gender"
    t.datetime "kbirthday"
    t.string "kbn"
    t.text "memo"
    t.string "mtel"
    t.string "name"
    t.string "no"
    t.string "position"
    t.string "ruby"
    t.string "section"
    t.string "section2"
    t.string "tel"
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "zip7"
  end

  create_table "keparts", force: :cascade do |t|
    t.string "comment"
    t.string "cordno"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "ename"
    t.string "form"
    t.string "itemno"
    t.string "jname"
    t.integer "munit"
    t.integer "newprice"
    t.string "pcode"
    t.integer "price"
    t.string "sel_unit"
    t.string "size"
    t.integer "stock"
    t.datetime "updated_at", null: false
    t.float "weightkg"
  end

  create_table "orderparts", force: :cascade do |t|
    t.integer "bqty"
    t.string "cordno"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "info"
    t.float "irate"
    t.string "itemno"
    t.string "kzaiko"
    t.integer "mno"
    t.date "ndate"
    t.string "partno"
    t.integer "qty"
    t.integer "sno"
    t.integer "total2"
    t.integer "totala"
    t.float "totalweight"
    t.string "unit"
    t.integer "unitpd"
    t.integer "unitpi"
    t.integer "unitpi2"
    t.float "unitweight"
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer "adlist_id"
    t.string "country"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "engno"
    t.string "etype"
    t.string "glc"
    t.string "glcno"
    t.string "hno"
    t.string "idate"
    t.string "inspection"
    t.float "irate"
    t.float "irate2"
    t.string "ldate"
    t.string "mdate"
    t.string "memo"
    t.string "mg"
    t.string "mgno"
    t.date "mitday"
    t.integer "mno"
    t.string "ncomment"
    t.string "ndate"
    t.integer "nebiki"
    t.string "nplase"
    t.string "odate"
    t.string "ono"
    t.string "orderitem"
    t.integer "pnum"
    t.date "rdate"
    t.date "seiday"
    t.string "shipname"
    t.string "st"
    t.date "syuday"
    t.string "tc"
    t.string "tcno"
    t.string "tcondition"
    t.string "tname"
    t.integer "tvalid"
    t.datetime "updated_at", null: false
    t.string "zp"
    t.string "zpno"
  end

  create_table "parts", force: :cascade do |t|
    t.string "comment"
    t.string "cordno"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "ename"
    t.string "form"
    t.string "itemno"
    t.string "jname"
    t.integer "munit"
    t.integer "newprice"
    t.string "pcode"
    t.integer "price"
    t.string "sel_unit"
    t.string "stock"
    t.datetime "updated_at", null: false
    t.float "weightkg"
  end

  create_table "registries", force: :cascade do |t|
    t.string "country"
    t.string "countryid"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.float "rate"
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stockbs", force: :cascade do |t|
    t.string "cname"
    t.string "cordno"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "ikubun"
    t.date "indate"
    t.integer "inprice"
    t.integer "invalue"
    t.integer "irprice"
    t.integer "irvalue"
    t.string "itemno"
    t.integer "kind"
    t.string "memo"
    t.integer "mno"
    t.integer "novalid"
    t.integer "num"
    t.integer "okubun"
    t.integer "onum"
    t.integer "orprice"
    t.integer "orvalue"
    t.date "outdate"
    t.string "partno"
    t.string "sname"
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_stockbs_on_id"
  end

  create_table "stocks", force: :cascade do |t|
    t.string "cname"
    t.string "cordno"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "ikubun"
    t.date "indate"
    t.integer "inprice"
    t.integer "invalue"
    t.integer "irprice"
    t.integer "irvalue"
    t.string "itemno"
    t.integer "kind"
    t.string "memo"
    t.integer "mno"
    t.integer "novalid"
    t.integer "num"
    t.integer "okubun"
    t.integer "onum"
    t.integer "orprice"
    t.integer "orvalue"
    t.date "outdate"
    t.string "partno"
    t.string "sname"
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_stocks_on_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "done"
    t.date "due"
    t.string "name"
    t.text "notes"
    t.integer "priority"
    t.datetime "updated_at", null: false
  end

  create_table "user_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "firstname"
    t.string "lastname"
    t.datetime "sign_in_at"
    t.datetime "sign_out_at"
    t.integer "state"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_profiles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "sessions", "users"
  add_foreign_key "user_profiles", "users"
end
