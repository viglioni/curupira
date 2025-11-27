defmodule <%= @project_name_camel_case %> do
	@moduledoc false

	alias ElixirScript.Web.Console
	
	@spec main() :: atom()
	def main do
	  Console.log("It's working!")
	end
end
