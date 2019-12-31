defmodule Norm.Contract do
  @moduledoc """
  Design by Contract with Norm.

  This module provides a `@contract` macro that can be used to define specs for arguments and the
  return value of a given function.

  To use contracts, call `use Norm` which also imports all `Norm` functions.

  Sometimes you may want to turn off contracts checking. For example, to skip contracts in production,
  set: `config :norm, enable_contracts: Mix.env != :prod`.

  ## Examples

      defmodule Colors do
        use Norm

        def rgb(), do: spec(is_integer() and &(&1 in 0..255))

        def hex(), do: spec(is_binary() and &String.starts_with?(&1, "#"))

        @contract rgb_to_hex(r :: rgb(), g :: rgb(), b :: rgb()) :: hex()
        def rgb_to_hex(r, g, b) do
          # ...
        end
      end

  """

  defstruct [:args, :result]

  @doc false
  defmacro __using__(_) do
    quote do
      import Kernel, except: [@: 1]
      Module.register_attribute(__MODULE__, :norm_contracts, accumulate: true)
      @before_compile Norm.Contract
      import Norm.Contract
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    definitions = Module.definitions_in(env.module)
    contracts = Module.get_attribute(env.module, :norm_contracts)

    for {name, arity} <- contracts do
      unless {name, arity} in definitions do
        raise ArgumentError, "contract for undefined function #{name}/#{arity}"
      end

      defconformer(name, arity)
    end
  end

  @doc false
  defmacro @{:contract, _, expr} do
    defcontract(expr)
  end

  defmacro @other do
    quote do
      Kernel.@(unquote(other))
    end
  end

  defp defconformer(name, arity) do
    args =
      List.duplicate(nil, arity)
      |> Enum.with_index()
      |> Enum.map(fn {_, index} -> Macro.var(:"arg#{index}", nil) end)

    quote do
      defoverridable [{unquote(name), unquote(arity)}]

      def unquote(name)(unquote_splicing(args)) do
        contract = __MODULE__.__contract__({unquote(name), unquote(arity)})

        for {val, {_arg, spec}} <- Enum.zip(unquote(args), contract.args) do
          Norm.conform!(val, spec)
        end

        result = super(unquote_splicing(args))
        Norm.conform!(result, contract.result)
        result
      end
    end
  end

  defp defcontract(expr) do
    if Application.get_env(:norm, :enable_contracts, true) do
      {name, args, result} = parse_contract_expr(expr)
      arity = length(args)

      quote do
        @doc false
        def __contract__({unquote(name), unquote(arity)}) do
          %Norm.Contract{args: unquote(args), result: unquote(result)}
        end

        @norm_contracts {unquote(name), unquote(arity)}
      end
    end
  end

  defp parse_contract_expr([{:"::", _, [{name, _, args}, result]}]) do
    args = Enum.map(args, &parse_arg/1)
    {name, args, result}
  end

  defp parse_contract_expr(expr) do
    actual = Macro.to_string({:@, [], [{:contract, [], expr}]})

    raise ArgumentError,
          "contract must be in the form " <>
            "`@contract function(arg :: spec) :: result_spec`, got: `#{actual}`"
  end

  defp parse_arg({:"::", _, [{name, _, _}, spec]}) do
    {name, spec}
  end

  defp parse_arg(expr) do
    raise ArgumentError,
          "argument spec must be in the form `arg :: spec`, " <>
            "got: `#{Macro.to_string(expr)}`"
  end
end
