class CreateKobeengineTables < ActiveRecord::Migration[8.1]
  def change
    create_table :adlists do |t|
      t.string :no
      t.string :kbn
      t.string :name
      t.string :ruby
      t.integer :gender
      t.datetime :birthday
      t.datetime :kbirthday
      t.string :zip7
      t.string :address1
      t.string :address2
      t.string :address3
      t.string :tel
      t.string :fax
      t.string :mtel
      t.string :url
      t.string :company
      t.string :section
      t.string :section2
      t.string :position
      t.string :cozip7
      t.string :coad1
      t.string :coad2
      t.string :coad3
      t.string :cotel
      t.string :comail
      t.string :cofax
      t.string :comobile
      t.string :copok
      t.string :email
      t.text :memo
      t.string :courl
      t.datetime :deleted_at
      t.timestamps null: false
    end

    create_table :keparts do |t|
      t.string :pcode
      t.string :form
      t.string :size
      t.string :jname
      t.string :ename
      t.integer :newprice
      t.integer :price
      t.integer :stock
      t.string :sel_unit
      t.float :weightkg
      t.integer :munit
      t.string :itemno
      t.string :cordno
      t.string :comment
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :orderparts do |t|
      t.integer :mno
      t.integer :sno
      t.string :itemno
      t.string :cordno
      t.string :kzaiko
      t.string :partno
      t.string :info
      t.integer :qty
      t.integer :bqty
      t.string :unit
      t.integer :unitpd
      t.integer :unitpi
      t.integer :unitpi2
      t.float :irate
      t.integer :totala
      t.integer :total2
      t.date :ndate
      t.float :unitweight
      t.float :totalweight
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :orders do |t|
      t.integer :tvalid
      t.integer :mno
      t.string :st
      t.integer :adlist_id
      t.date :rdate
      t.string :ncomment
      t.string :ndate
      t.string :nplase
      t.string :ldate
      t.string :tcondition
      t.string :etype
      t.string :engno
      t.string :shipname
      t.string :country
      t.integer :pnum
      t.string :inspection
      t.string :hno
      t.string :orderitem
      t.string :memo
      t.string :tname
      t.string :idate
      t.string :odate
      t.string :mdate
      t.float :irate
      t.integer :nebiki
      t.float :irate2
      t.string :tc
      t.string :tcno
      t.string :zp
      t.string :zpno
      t.string :glc
      t.string :glcno
      t.string :mg
      t.string :mgno
      t.string :ono
      t.date :mitday
      t.date :syuday
      t.date :seiday
      t.datetime :deleted_at
      t.timestamps null: false
    end

    create_table :parts do |t|
      t.string :pcode
      t.string :form
      t.string :jname
      t.string :ename
      t.string :stock
      t.string :sel_unit
      t.integer :price
      t.integer :newprice
      t.float :weightkg
      t.integer :munit
      t.string :itemno
      t.string :cordno
      t.string :comment
      t.datetime :deleted_at
      t.timestamps null: false
    end

    create_table :registries do |t|
      t.string :countryid
      t.string :country
      t.float :rate
      t.datetime :deleted_at
      t.timestamps null: false
    end

    create_table :stocks do |t|
      t.string :partno
      t.integer :kind
      t.date :indate
      t.integer :num
      t.integer :inprice
      t.integer :irprice
      t.integer :invalue
      t.integer :irvalue
      t.date :outdate
      t.integer :onum
      t.integer :mno
      t.integer :orprice
      t.integer :orvalue
      t.string :itemno
      t.string :cordno
      t.string :memo
      t.string :cname
      t.string :sname
      t.integer :novalid
      t.integer :ikubun
      t.integer :okubun
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :stocks, :id

    create_table :stockbs do |t|
      t.string :partno
      t.integer :kind
      t.date :indate
      t.integer :num
      t.integer :inprice
      t.integer :irprice
      t.integer :invalue
      t.integer :irvalue
      t.date :outdate
      t.integer :onum
      t.integer :mno
      t.integer :orprice
      t.integer :orvalue
      t.string :itemno
      t.string :cordno
      t.string :memo
      t.string :cname
      t.string :sname
      t.integer :novalid
      t.integer :ikubun
      t.integer :okubun
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :stockbs, :id

    create_table :tasks do |t|
      t.boolean :done
      t.string :name
      t.text :notes
      t.integer :priority
      t.date :due
      t.timestamps null: false
    end
  end
end
