defmodule Fixtures.TypedStructs do
  use TypedStruct

  typedstruct module: Person do
    field :name, String.t(), enforce: true
    field :age, integer(), default: 0
    field :email, String.t()
  end

  typedstruct module: Product do
    field :title, String.t(), enforce: true
    field :price, float(), default: 0.0
    field :in_stock, boolean(), default: true
  end

  def create_person(name) do
    %Person{name: name, age: 25}
  end

  def update_person(person, new_age) do
    %{person | age: new_age}
  end

  def pattern_match_person(%Person{name: name, age: age}) when age >= 18 do
    "Adult: #{name}"
  end
end
