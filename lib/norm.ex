defmodule Norm do
  defmodule Mismatch do
    def new(path, input, predicate) do
      %{path: path, input: input, predicate: predicate}
    end
  end

  def conform(spec, input) do
    path = []
  end

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :schemas, accumulate: true)
    end
  end

  defmacro req(key, spec) when is_atom(key) do
  end

  def schema(opts) do
    reqs =
      opts
      |> Keyword.get(:reqs, [])
      |> Enum.map(&req_key/1)

    opts =
      opts
      |> Keyword.get(:opts, [])
      |> Enum.map(&opt_key/1)

    keys = reqs ++ opts

    fn path, input ->
      keys
    end
  end

  defp req_key({key, spec}) do
    fn path, input ->
      actual = input[key]

      if is_nil(actual) do
        {:error, Mismatch.new(path ++ [key], input, "required")}
      else
        {:ok, spec.(path ++ [key], actual)}
      end
    end
  end

  defp opt_key({key, spec}) do
    fn path, input ->
      actual = input[key]

      if is_nil(actual) do
        {:ok, input}
      else
        {:ok, spec.(path ++ [key], actual)}
      end
    end
  end

  defmacro req(key, predicate) when is_atom(key) do
    quote do
    end
  end

  def integer?() do
    fn path, input ->
      case is_integer(input) do
        true  -> {:ok, input}
        false -> Mismatch.new(path, input, "integer?")
      end
    end
  end

  def string?() do
    fn path, input ->
      case is_binary(input) do
        true  -> {:ok, input}
        false -> Mismatch.new(path, input, "string?")
      end
    end
  end

  def lit(literal) do
    fn path, input ->
      if literal == input do
        {:ok, input}
      else
        Mismatch.new(path, input, "string?")
      end
    end
  end

  def re_matches?(regex) do
    fn path, input when is_binary(input) ->
      if String.match?(input, regex) do
        {:ok, input}
      else
        Mismatch.new(path, input, "re_matches?#{inspect regex}")
      end
    end
  end
end

