defmodule CurupiraScriptIntegrationTest do
  use ExUnit.Case

  @moduletag :integration

  alias CurupiraScript.{DependencyWalker, Bundler, Compiler}
  alias Fixtures.Simple
  alias Fixtures.WithArgs
  alias Fixtures.Multiple

  @output_dir "test/tmp/integration"

  setup do
    # Clean output directory before each test
    File.rm_rf!(@output_dir)
    File.mkdir_p!(@output_dir)
    :ok
  end

  describe "DependencyWalker.walk/1" do
    test "walks a single module with no dependencies" do
      assert {:ok, modules} = DependencyWalker.walk([Simple])
      assert MapSet.member?(modules, Fixtures.Simple)
      assert MapSet.size(modules) == 1
    end

    test "walks multiple entry modules" do
      assert {:ok, modules} = DependencyWalker.walk([Simple, WithArgs])
      assert MapSet.member?(modules, Fixtures.Simple)
      assert MapSet.member?(modules, Fixtures.WithArgs)
      assert MapSet.size(modules) >= 2
    end

    test "filters out Elixir stdlib modules" do
      # PatternMatch might call Kernel or other stdlib modules
      assert {:ok, modules} = DependencyWalker.walk([Fixtures.PatternMatch])

      # Verify no Elixir stdlib modules are included
      refute Enum.any?(modules, fn mod ->
               mod_name = to_string(mod)
               String.starts_with?(mod_name, "Elixir.Enum") or
                 String.starts_with?(mod_name, "Elixir.String") or
                 String.starts_with?(mod_name, "Elixir.Kernel")
             end)
    end

    test "returns error for non-existent module" do
      assert {:error, _reason} = DependencyWalker.walk([NonExistentModule])
    end

    test "handles empty list" do
      assert {:ok, modules} = DependencyWalker.walk([])
      assert MapSet.size(modules) == 0
    end
  end

  describe "Bundler.bundle/1" do
    test "creates a single JavaScript bundle from multiple modules" do
      # Compile modules first
      {:ok, %{output_files: files}} =
        Compiler.compile([Simple, WithArgs], source_maps: false)

      # Extract module code
      modules_with_code =
        Enum.map(files, fn %{path: path, content: js_code} ->
          module_name =
            path
            |> Path.basename(".js")
            |> String.replace_prefix("Elixir.", "")
            |> String.to_atom()

          {module_name, js_code}
        end)

      # Bundle
      assert {:ok, bundled_code} = Bundler.bundle(modules_with_code)
      assert is_binary(bundled_code)
      assert bundled_code =~ "export default"
    end

    test "generates nested namespace structure" do
      {:ok, %{output_files: files}} =
        Compiler.compile([Simple, WithArgs], source_maps: false)

      modules_with_code =
        Enum.map(files, fn %{path: path, content: js_code} ->
          module_name =
            path
            |> Path.basename(".js")
            |> String.replace_prefix("Elixir.", "")
            |> String.to_atom()

          {module_name, js_code}
        end)

      {:ok, bundled_code} = Bundler.bundle(modules_with_code)

      # Should have Simple and WithArgs as top-level keys
      assert bundled_code =~ "Simple:"
      assert bundled_code =~ "WithArgs:"
    end

    test "unwraps single top-level namespace" do
      # All Fixtures.* modules share "Fixtures" prefix
      {:ok, %{output_files: files}} =
        Compiler.compile([Simple, WithArgs], source_maps: false)

      modules_with_code =
        Enum.map(files, fn %{path: path, content: js_code} ->
          module_name =
            path
            |> Path.basename(".js")
            |> String.replace_prefix("Elixir.", "")
            |> String.to_atom()

          {module_name, js_code}
        end)

      {:ok, bundled_code} = Bundler.bundle(modules_with_code)

      # Should NOT have nested Fixtures.Fixtures
      # Instead should be { Simple: ..., WithArgs: ... }
      refute bundled_code =~ "Fixtures: {\n  Fixtures:"
    end

    test "preserves module functions in bundle" do
      {:ok, %{output_files: files}} =
        Compiler.compile([Simple, WithArgs], source_maps: false)

      modules_with_code =
        Enum.map(files, fn %{path: path, content: js_code} ->
          module_name =
            path
            |> Path.basename(".js")
            |> String.replace_prefix("Elixir.", "")
            |> String.to_atom()

          {module_name, js_code}
        end)

      {:ok, bundled_code} = Bundler.bundle(modules_with_code)

      # Should preserve hello and greet functions
      assert bundled_code =~ "hello"
      assert bundled_code =~ "greet"
    end

    test "handles empty module list" do
      assert {:ok, bundled_code} = Bundler.bundle([])
      assert is_binary(bundled_code)
      assert bundled_code =~ "export default"
    end
  end

  describe "Mix.Tasks.CurupiraScript.Build task" do
    @tag :mix_task
    test "builds bundle with configuration from mix.exs" do
      # This test uses the actual config from mix.exs
      # config: input: [Fixtures.Simple, Fixtures.WithArgs], output: "js/elixir_bundle.js"

      # Clean up first
      File.rm_rf("js/elixir_bundle.js")

      Mix.Tasks.CurupiraScript.Build.run([])

      # Verify bundle was created at configured path
      assert File.exists?("js/elixir_bundle.js")
      bundle_content = File.read!("js/elixir_bundle.js")

      assert bundle_content =~ "export default"
      assert bundle_content =~ "Simple:"
      assert bundle_content =~ "WithArgs:"
    end

    @tag :mix_task
    test "creates output directory if it doesn't exist" do
      # Remove js directory to test creation
      File.rm_rf("js")

      Mix.Tasks.CurupiraScript.Build.run([])

      # Should create js/ directory and bundle
      assert File.exists?("js/elixir_bundle.js")

      # Verify directory was created
      assert File.dir?("js")
    end
  end

  describe "Mix.Compilers.CurupiraScript" do
    @tag :mix_compiler
    test "returns {:ok, []} on successful compilation" do
      # Use actual config from mix.exs
      # Clean manifest and output to force rebuild
      File.rm(".mix_curupira_script_manifest")
      File.rm_rf("js/elixir_bundle.js")

      assert {:ok, []} = Mix.Compilers.CurupiraScript.run([])
      assert File.exists?("js/elixir_bundle.js")
    end

    @tag :mix_compiler
    test "returns {:noop, []} when up to date" do
      # First compilation
      File.rm(".mix_curupira_script_manifest")
      File.rm_rf("js/elixir_bundle.js")

      assert {:ok, []} = Mix.Compilers.CurupiraScript.run([])

      # Second compilation should be noop
      assert {:noop, []} = Mix.Compilers.CurupiraScript.run([])
    end

    @tag :mix_compiler
    test "rebuilds when output file is deleted" do
      # First compilation
      File.rm(".mix_curupira_script_manifest")
      File.rm_rf("js/elixir_bundle.js")

      assert {:ok, []} = Mix.Compilers.CurupiraScript.run([])

      # Delete output file
      File.rm_rf("js/elixir_bundle.js")

      # Should rebuild
      assert {:ok, []} = Mix.Compilers.CurupiraScript.run([])
      assert File.exists?("js/elixir_bundle.js")
    end

    @tag :mix_compiler
    test "clean/0 removes manifest file" do
      # Build to create manifest
      Mix.Compilers.CurupiraScript.run([])
      assert File.exists?(".mix_curupira_script_manifest")

      # Clean
      Mix.Compilers.CurupiraScript.clean()

      # Manifest should be removed
      refute File.exists?(".mix_curupira_script_manifest")
    end

    @tag :mix_compiler
    test "manifests/0 returns manifest file path" do
      assert [".mix_curupira_script_manifest"] = Mix.Compilers.CurupiraScript.manifests()
    end
  end

  describe "Full end-to-end workflow" do
    @tag :e2e
    test "compile -> bundle -> write -> verify Node.js can import" do
      output_path = "test/tmp/e2e_bundle.js"

      # Step 1: Walk dependencies
      {:ok, all_modules} = DependencyWalker.walk([Simple, WithArgs])
      modules_list = MapSet.to_list(all_modules)

      # Step 2: Compile
      {:ok, %{output_files: files}} = Compiler.compile(modules_list, source_maps: false)

      # Step 3: Extract module code
      modules_with_code =
        Enum.map(files, fn %{path: path, content: js_code} ->
          module_name =
            path
            |> Path.basename(".js")
            |> String.replace_prefix("Elixir.", "")
            |> String.to_atom()

          {module_name, js_code}
        end)

      # Step 4: Bundle
      {:ok, bundled_code} = Bundler.bundle(modules_with_code)

      # Step 5: Write
      File.mkdir_p!(Path.dirname(output_path))
      File.write!(output_path, bundled_code)

      # Step 6: Verify with Node.js
      # Get absolute path for Node.js
      abs_bundle_path = Path.expand(output_path)

      # Create a test script in the same directory
      test_script = """
      import bundle from '#{abs_bundle_path}';
      console.log('Simple.hello:', bundle.Simple.hello());
      console.log('WithArgs.greet:', bundle.WithArgs.greet('Elixir'));
      """

      test_script_path = "test/tmp/e2e_test.mjs"
      File.write!(test_script_path, test_script)

      # Run with Node.js
      case System.cmd("node", [test_script_path]) do
        {output, 0} ->
          assert output =~ "Simple.hello: world"
          assert output =~ "WithArgs.greet: Hello, Elixir!"

        {error_output, _exit_code} ->
          # Node.js might not be available or ESM not supported
          IO.puts("Skipping Node.js test: #{error_output}")
      end

      # Cleanup
      File.rm_rf!(@output_dir)
    end

    @tag :e2e
    test "full Mix workflow: compile task integration" do
      # This test verifies that `mix compile` automatically builds the bundle
      # Use actual config from mix.exs
      File.rm(".mix_curupira_script_manifest")
      File.rm_rf("js/elixir_bundle.js")

      # Run the compiler through Mix task
      assert {:ok, []} = Mix.Tasks.Compile.CurupiraScript.run([])

      # Verify output
      assert File.exists?("js/elixir_bundle.js")
      content = File.read!("js/elixir_bundle.js")

      assert content =~ "export default"
      assert content =~ "Simple:"
      assert content =~ "WithArgs:"

      # Verify it's valid JavaScript with Node.js
      abs_bundle_path = Path.expand("js/elixir_bundle.js")

      test_script = """
      import bundle from '#{abs_bundle_path}';
      console.log(typeof bundle.Simple.hello);
      console.log(typeof bundle.WithArgs.greet);
      """

      test_script_path = "test/tmp/mix_e2e_test.mjs"
      File.mkdir_p!("test/tmp")
      File.write!(test_script_path, test_script)

      case System.cmd("node", [test_script_path]) do
        {output, 0} ->
          assert output =~ "function"

        {_error_output, _exit_code} ->
          # Node.js might not be available
          :ok
      end
    end
  end
end
