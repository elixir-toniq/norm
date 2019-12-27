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

  @doc false
  def __before_compile__(env) do
    contracts = Module.get_attribute(env.module, :norm_contracts)
    definitions = Module.definitions_in(env.module)

    for {fun, arity} <- contracts do
      unless {:"__#{fun}_without_contract__", arity} in definitions do
        raise ArgumentError, "contract for undefined function #{fun}/#{arity}"
      end
    end
  end

  @doc false
  defmacro __using__(_) do
    quote do
      import Kernel, except: [@: 1, def: 2]
      import Norm.Contract
      Module.register_attribute(__MODULE__, :norm_contracts, accumulate: true)
      @before_compile Norm.Contract
    end
  end

  @doc false
  defmacro def(call, expr) do
    quote do
      if unquote(fa(call)) in @norm_contracts do
        unless Module.defines?(__MODULE__, unquote(fa(call))) do
          Kernel.def(unquote(wrapper_call(call)), do: unquote(wrapper_body(call)))
        end

        Kernel.def(unquote(call_without_contract(call)), unquote(expr))
      else
        Kernel.def(unquote(call), unquote(expr))
      end
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

  ## Internals

  defp defcontract(expr) do
    if Application.get_env(:norm, :enable_contracts, true) do
      do_defcontract(expr)
    end
  end

  defp do_defcontract(expr) do
    {call, result_spec} =
      case expr do
        [{:"::", _, [call, result_spec]}] ->
          {call, result_spec}

        _ ->
          actual = Macro.to_string({:@, [], [{:contract, [], expr}]})

          raise ArgumentError,
                "contract must be in the form " <>
                  "`@contract function(arg :: spec) :: result_spec`, got: `#{actual}`"
      end

    {name, call_meta, arg_specs} = call

    arg_vars =
      for arg_spec <- arg_specs do
        case arg_spec do
          {:"::", _, [{arg_name, _, _}, _spec]} ->
            Macro.var(arg_name, nil)

          _ ->
            raise ArgumentError,
                  "argument spec must be in the form `arg :: spec`, " <>
                    "got: `#{Macro.to_string(arg_spec)}`"
        end
      end

    conform_args =
      for {:"::", _, [{arg_name, _, _}, spec]} <- arg_specs do
        arg = Macro.var(arg_name, nil)

        quote do
          Norm.conform!(unquote(arg), unquote(spec))
        end
      end

    conform_args = {:__block__, [], conform_args}
    result = Macro.var(:result, nil)
    call = {name, call_meta, arg_vars}

    quote do
      @norm_contracts unquote(fa(call))

      def unquote(call_with_contract(call)) do
        unquote(conform_args)
        unquote(result) = unquote(call_without_contract(call))
        Norm.conform!(unquote(result), unquote(result_spec))
        unquote(result)
      end
    end
  end

  ## Utilities

  defp wrapper_call(call) do
    {name, meta, args} = call
    args = for {_, index} <- Enum.with_index(args), do: Macro.var(:"arg#{index}", nil)
    {name, meta, args}
  end

  defp wrapper_body(call) do
    {name, meta, args} = call
    args = for {_, index} <- Enum.with_index(args), do: Macro.var(:"arg#{index}", nil)
    {:"__#{name}_with_contract__", meta, args}
  end

  defp call_with_contract(call) do
    {name, meta, args} = call
    {:"__#{name}_with_contract__", meta, args}
  end

  defp call_without_contract(call) do
    {name, meta, args} = call
    {:"__#{name}_without_contract__", meta, args}
  end

  defp fa(call) do
    {name, _meta, args} = call
    {name, length(args)}
  end
end
