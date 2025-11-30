defmodule Fixtures.Structs do
  defmodule User do
    defstruct [:name, :age, :email]
  end

  defmodule Post do
    defstruct [:title, :body, author: nil, published: false]
  end

  def create_user do
    %User{name: "Alice", age: 30, email: "alice@example.com"}
  end

  def create_user_partial do
    %User{name: "Bob"}
  end

  def update_user(user) do
    %{user | age: 31}
  end

  def pattern_match_user(%User{name: name}) do
    name
  end
end
