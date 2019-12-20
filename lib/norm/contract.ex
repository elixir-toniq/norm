defmodule Norm.Contract do
  @moduledoc """
  Design by Contract with Norm.

  This module provides a `@contract` macro that can be used to define specs for arguments and the
  return value of a given function and optionally additional pre- and post-conditions.

  To use contracts, call `use Norm` which also imports all `Norm` functions.

  ## Options

    * `:requires` - a function that can be used to check arbitrary pre-conditions.
      The function receives the same arguments as the function under contract.

    * `:ensures` - a function that can be used to check arbitrary post-conditions. The function
      receives the same arguments as the function under contract as well as the result of the
      function call as the last argument.

    * `:enabled` - By default are contracts are enforced at runtime. This behaviour can be changed
      on a per-contract basis by setting this option or globally by setting `:enable_contracts`
      configuration for `:norm` application. For example, to skip all contracts in production, set:
      `config :norm, enable_contracts: Mix.env != :prod`.

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

  Besides ensuring arguments and return value conforms to a particular `Norm.Spec`,
  arbitrary pre- and post-conditions can be specified. For post-conditions,
  a `result` binding is provided to access the return value of the function.

      @contract rgb_to_hex(r :: rgb(), g :: rgb(), b :: rgb()) :: hex(),
        requires: fn r, _, _ -> r != 42 end,
        ensures: fn _, _, _, result -> result != "#FFFFFF" end
      def rgb_to_hex(r, g, b) do
        # ...
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

  defp defcontract([_] = expr) do
    if enabled?([]) do
      do_defcontract(expr)
    end
  end

  defp defcontract([_, options] = expr) do
    if enabled?(options) do
      do_defcontract(expr)
    end
  end

  defp enabled?(options) do
    case Keyword.fetch(options, :enabled) do
      {:ok, enabled} -> enabled
      :error -> Application.get_env(:norm, :enable_contracts, true)
    end
  end

  defp do_defcontract(expr) do
    {call, result_spec, guards} =
      case expr do
        [{:"::", _, [call, result_spec]}, guards] ->
          {call, result_spec, guards}

        [{:"::", _, [call, result_spec]}] ->
          {call, result_spec, []}

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

    run_requires =
      if guards[:requires] do
        quote do
          unless apply(unquote(guards[:requires]), unquote(arg_vars)) do
            raise "pre-condition failed: #{unquote(Macro.to_string(guards[:requires]))}"
          end
        end
      end

    result = Macro.var(:result, nil)

    run_ensures =
      if guards[:ensures] do
        quote do
          unless apply(unquote(guards[:ensures]), unquote(arg_vars) ++ [unquote(result)]) do
            raise "post-condition failed: #{unquote(Macro.to_string(guards[:ensures]))}"
          end
        end
      end

    call = {name, call_meta, arg_vars}

    quote do
      @norm_contracts unquote(fa(call))

      def unquote(call_with_contract(call)) do
        unquote(conform_args)
        unquote(run_requires)
        unquote(result) = unquote(call_without_contract(call))
        Norm.conform!(unquote(result), unquote(result_spec))
        unquote(run_ensures)
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
