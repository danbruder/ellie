defmodule Elm.Platform.Parser do
  use Combine, parsers: [:text]
  alias Data.Json.Decode
  alias Data.Function
  alias Elm.Docs.Binop
  alias Elm.Docs.Value
  alias Elm.Docs.Union
  alias Elm.Docs.Alias
  alias Elm.Docs.Module
  alias Elm.Searchable
  alias Elm.Version
  alias Elm.Name

  def module_name(text) do
    text
    |> run(module_name_parser())
    |> with_default("Main")
  end

  def module_path(text) do
    String.replace(module_name(text), ".", "/") <> ".elm"
  end

  defp module_name_parser() do
    choice([
      ignore(string("module")),
      ignore(string("port")) |> ignore(spaces()) |> ignore(string("module")),
      ignore(string("effect")) |> ignore(spaces()) |> ignore(string("module")),
    ])
    |> ignore(spaces())
    |> map(sep_by1(word_of(~r/[A-Z][a-zA-Z0-9_]+/), char(".")), &Enum.join(&1, "."))
  end

  defp run(text, parser) do
    case Combine.parse(text, parser) do
      {:error, _} -> nil
      stuff -> List.first(stuff)
    end
  end

  defp with_default(nil, a), do: a
  defp with_default(a, _a), do: a

  def searchables_json(body) do
    Decode.decode_string(body, searchables_decoder())
  end

  def searchables_decoder() do
    version =
      Decode.and_then(Decode.string, fn string ->
        case Version.from_string(string) do
          {:ok, version} -> Decode.succeed(version)
          :error -> Decode.fail("Expecting a version MAJOR.MINOR.PATCH")
        end
      end)

    name =
      Decode.and_then(Decode.string, fn string ->
        case Name.from_string(string) do
          {:ok, name} -> Decode.succeed(name)
          :error -> Decode.fail("Expecting a name USER/PROJECT")
        end
      end)

    searchable =
      Decode.succeed(Function.curry(&%Searchable{name: &1, summary: &2, versions: &3}))
      |> Decode.and_map(Decode.field("name", name))
      |> Decode.and_map(Decode.field("summary", Decode.string))
      |> Decode.and_map(Decode.field("versions", Decode.list(version)))

    Decode.list(searchable)
  end

  def docs_json(body) do
    Decode.decode_string(body, docs_decoder())
  end

  defp docs_decoder() do
    associativity =
      Decode.and_then(Decode.string, fn
        "left" -> Decode.succeed :left
        "non" -> Decode.succeed :none
        "right" -> Decode.succeed :right
        _ -> Decode.fail "expecting one of the following values: left, non, right"
      end)

    binop =
      Decode.succeed(Function.curry(&%Binop{name: &1, comment: &2, type: &3, associativity: &4, precedence: &5}))
      |> Decode.and_map(Decode.field("name", Decode.string))
      |> Decode.and_map(Decode.field("comment", Decode.string))
      |> Decode.and_map(Decode.field("type", Decode.string))
      |> Decode.and_map(Decode.field("associativity", associativity))
      |> Decode.and_map(Decode.field("precedence", Decode.integer))

    value =
      Decode.succeed(Function.curry(&%Value{name: &1, comment: &2, type: &3}))
      |> Decode.and_map(Decode.field("name", Decode.string))
      |> Decode.and_map(Decode.field("comment", Decode.string))
      |> Decode.and_map(Decode.field("type", Decode.string))

    tag =
      Decode.succeed(Function.curry(&{&1, &2}))
      |> Decode.and_map(Decode.index(0, Decode.string))
      |> Decode.and_map(Decode.index(1, Decode.list(Decode.string)))

    union =
      Decode.succeed(Function.curry(&%Union{name: &1, comment: &2, args: &3, tags: &4}))
      |> Decode.and_map(Decode.field("name", Decode.string))
      |> Decode.and_map(Decode.field("comment", Decode.string))
      |> Decode.and_map(Decode.field("args", Decode.list(Decode.string)))
      |> Decode.and_map(Decode.field("cases", Decode.list(tag)))

    aliasd =
      Decode.succeed(Function.curry(&%Alias{name: &1, comment: &2, args: &3, type: &4}))
      |> Decode.and_map(Decode.field("name", Decode.string))
      |> Decode.and_map(Decode.field("comment", Decode.string))
      |> Decode.and_map(Decode.field("args", Decode.list(Decode.string)))
      |> Decode.and_map(Decode.field("type", Decode.string))

    moduled =
      Decode.succeed(Function.curry(&%Module{name: &1, comment: &2, unions: &3, aliases: &4, values: &5, binops: &6}))
      |> Decode.and_map(Decode.field("name", Decode.string))
      |> Decode.and_map(Decode.field("comment", Decode.string))
      |> Decode.and_map(Decode.field("unions", Decode.list(union)))
      |> Decode.and_map(Decode.field("aliases", Decode.list(aliasd)))
      |> Decode.and_map(Decode.field("values", Decode.list(value)))
      |> Decode.and_map(Decode.field("binops", Decode.list(binop)))

    Decode.list(moduled)
  end
end