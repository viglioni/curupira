defmodule Mix.Tasks do
  defmodule __MODULE__.Watch.Compile do
    use Mix.Task

    @shortdoc "Watch files and compile on change"
    def run(_) do
      # Start all required applications
      Application.ensure_all_started(:exsync)

      # Configure Exsync 
      Application.put_env(:exsync, :reload_callback, {Mix.Task, :rerun, ["compile"]})
      Application.put_env(:exsync, :extensions, [".ex", ".exs"])

      # Get port from config
      port = Application.get_env(:<%= @project_name %>, :port, 5050)
      
      spawn(fn ->
        System.cmd("npm", ["run", "dev"], env: [{"PORT", to_string(port)}], into: IO.stream(:stdio, :line))
      end)

      # Keep the process running
      Process.sleep(:infinity)
    end
  end

  defmodule __MODULE__.Port.Kill do
    use Mix.Task
    require Logger

    @shortdoc "Kill process using port from config, defaulting to 5050"
    def run(_) do
      port_number = Application.get_env(:<%= @project_name %>, :port, 5050)
      Logger.info("Finding process using port #{port_number}...")

      with {output, 0} <- System.cmd("sh", ["-c", "lsof -ti :#{port_number}"]),
           pid <- String.trim(output),
           _ <- Logger.info("Killing process #{pid}..."),
           {_, 0} <- System.cmd("kill", ["-9", pid]),
           _ <- Logger.info("Process killed.") do
        :ok
      else
        {_error, 1} ->
          Logger.info("No process found in port #{port_number}.")
          :ok

        {error, code} ->
          Logger.error("Command failed with code #{code}: #{error}")

          :error
      end
    end
  end
end
