require "test_helper"
require "tmpdir"

# システム管理画面のバージョン情報（SystemInfo）のテスト
class SystemInfoTest < ActiveSupport::TestCase
  # 一時ディレクトリに .node-version と node_modules/<パッケージ>/package.json を作って渡す
  def with_fake_root(node_version: "99.9.9", packages: {})
    Dir.mktmpdir do |dir|
      root = Pathname(dir)
      File.write(root.join(".node-version"), "#{node_version}\n") if node_version
      packages.each do |name, content|
        FileUtils.mkdir_p(root.join("node_modules", name))
        File.write(root.join("node_modules", name, "package.json"), content)
      end
      yield root
    end
  end

  def version_of(items, name)
    items.find { |item| item.name == name }.version
  end

  test "items are in the order Ruby, Rails, Node.js, Tailwind CSS, daisyUI" do
    assert_equal [ "Ruby", "Rails", "Node.js", "Tailwind CSS", "daisyUI" ], SystemInfo.items.map(&:name)
  end

  test "Ruby and Rails come from the running process" do
    items = SystemInfo.items
    assert_equal RUBY_VERSION, version_of(items, "Ruby")
    assert_equal Rails.version, version_of(items, "Rails")
  end

  test "Node.js comes from .node-version of the repository" do
    expected = File.read(Rails.root.join(".node-version")).strip
    assert_equal expected, version_of(SystemInfo.items, "Node.js")
  end

  test "Node.js, Tailwind CSS and daisyUI are read from the given root" do
    packages = {
      "tailwindcss" => '{"name":"tailwindcss","version":"4.3.5"}',
      "daisyui" => '{"name":"daisyui","version":"5.7.50"}'
    }
    with_fake_root(node_version: "26.13.0", packages: packages) do |root|
      items = SystemInfo.items(root: root)
      assert_equal "26.13.0", version_of(items, "Node.js")
      assert_equal "4.3.5", version_of(items, "Tailwind CSS")
      assert_equal "5.7.50", version_of(items, "daisyUI")
    end
  end

  test "a root given as a String works too" do
    with_fake_root(node_version: "26.13.0") do |root|
      assert_equal "26.13.0", version_of(SystemInfo.items(root: root.to_s), "Node.js")
    end
  end

  test "versions that cannot be read are nil, not an error" do
    with_fake_root(node_version: nil) do |root|
      items = SystemInfo.items(root: root)
      assert_nil version_of(items, "Node.js")
      assert_nil version_of(items, "Tailwind CSS")
      assert_nil version_of(items, "daisyUI")
      # Ruby と Rails は影響を受けない
      assert_equal RUBY_VERSION, version_of(items, "Ruby")
    end
  end

  test "a blank .node-version is nil" do
    with_fake_root(node_version: "  ") do |root|
      assert_nil version_of(SystemInfo.items(root: root), "Node.js")
    end
  end

  test "a broken or versionless package.json is nil" do
    packages = {
      "tailwindcss" => "{ this is not json",
      "daisyui" => '{"name":"daisyui"}'
    }
    with_fake_root(packages: packages) do |root|
      items = SystemInfo.items(root: root)
      assert_nil version_of(items, "Tailwind CSS")
      assert_nil version_of(items, "daisyUI")
    end
  end

  test "a package.json that is not a JSON object is nil" do
    with_fake_root(packages: { "tailwindcss" => '["4.3.5"]', "daisyui" => '{"version":5}' }) do |root|
      items = SystemInfo.items(root: root)
      assert_nil version_of(items, "Tailwind CSS")
      assert_nil version_of(items, "daisyUI")
    end
  end
end
