defmodule HashRing.Driver do
  @moduledoc """
  A helper library for loading, starting, stopping, and communicating to an Erlang
  port to the C hash-ring library.

  All functions are synchronous unless explicitly specified.
  """

  @driver "hash_ring_drv"
  @port_timeout 5000

  @hash_function_sha1 1
  @hash_function_md5 2
  @hash_functions [
    @hash_function_md5,
    @hash_function_sha1,
  ]

  @mode_normal 1
  @mode_libmemcached_compat 2
  @modes [
    @mode_normal,
    @mode_libmemcached_compat,
  ]

  @doc """
  Add a node to a hash ring.
  """
  @spec add(pid, integer, binary) :: :ok | {:error, atom}
  def add(_, _, []), do: :ok
  def add(port, index, [node|rest]) do
    case add(port, index, node) do
      :ok ->
        add(port, index, rest)
      error ->
        error
    end
  end
  def add(port, index, node) when not is_binary(node), do: add(port, index, to_string(node))
  def add(port, index, node) do
    command(port, <<3::size(8), index::size(32), byte_size(node)::size(32), node::binary>>)
    receive do
      {port = port, {:data, <<0::size(8)>>}} ->
        :ok
      {port = port, {:data, <<1::size(8)>>}} ->
        {:error, :driver_error}
    after
      @port_timeout ->
        {:error, :port_timeout}
    end
  end

  @doc """
  Close an open driver.
  """
  @spec close(pid) :: :ok
  def close(port) do
    send(port, {self, :close})
    receive do
      {port = port, :closed} ->
        :ok
    end
  end

  @doc """
  Create a new ring in an open port.
  """
  @spec create(pid, integer, atom | integer) :: {:ok, integer} | {:error, atom}
  def create(port, replicas, :md5), do: create(port, replicas, @hash_function_md5)
  def create(port, replicas, :sha1), do: create(port, replicas, @hash_function_sha1)
  def create(port, replicas, hash_func) when hash_func in @hash_functions do
    command(port, <<1::size(8), replicas::size(32), hash_func::size(8)>>)
    receive do
      {port = port, {:data, <<index::size(32)>>}} ->
        {:ok, index}
    after
      @port_timeout ->
        {:error, :port_timeout}
    end
  end
  def create(_, _, _), do: {:error, :unsupported_hash_func}

  @doc """
  Drop a node from a hash ring.
  """
  @spec drop(pid, integer, binary) :: :ok | {:error, atom}
  def drop(port, index, node) when not is_binary(node), do: drop(port, index, to_string(node))
  def drop(port, index, node) do
    command(port, <<4::size(8), index::size(32), byte_size(node)::size(32), node::binary>>)
    receive do
      {port = port, {:data, <<0::size(8)>>}} ->
        :ok
      {port = port, {:data, <<1::8>>}} ->
        {:error, :driver_error}
    after
      @port_timeout ->
        {:error, :port_timeout}
    end
  end

  @doc """
  Find the appropriate node for the given key in a hash ring.
  """
  @spec find(pid, integer, binary) :: {:ok, binary} | {:error, atom}
  def find(port, index, key) when not is_binary(key), do: find(port, index, to_string(key))
  def find(port, index, key) do
    command(port, <<5::size(8), index::size(32), byte_size(key)::size(32), key::binary>>)
    receive do
      {port = port, {:data, <<3::size(8)>>}} ->
        {:error, :invalid_ring}
      {port = port, {:data, <<2::size(8)>>}} ->
        {:error, :node_not_found}
      {port = port, {:data, <<1::size(8)>>}} ->
        {:error, :no_nodes}
      {port = port, {:data, <<node::binary>>}} ->
        {:ok, node}
    end
  end

  @doc """
  Load the port driver.
  """
  @spec load :: :ok | {:error, term}
  def load do
    case :erl_ddll.load_driver(lib_path, @driver) do
      :ok ->
        :ok
      {:error, :already_loaded} ->
        :ok
      {:error, message} ->
        exit(:erl_ddll.format_error(message))
    end
  end

  @doc """
  Set the mode for the given ring.
  """
  @spec set_mode(pid, integer, atom | integer) :: :ok | {:error, atom}
  def set_mode(port, index, :normal), do: set_mode(port, index, @mode_normal)
  def set_mode(port, index, :memcached), do: set_mode(port, index, @mode_libmemcached_compat)
  def set_mode(port, index, mode) when mode in @modes do
    command(port, <<6::size(8), index::size(32), mode::size(8)>>)
    receive do
      {port = port, {:data, <<0::size(8)>>}} ->
        :ok
      {port = port, {:data, <<1::size(8)>>}} ->
        {:error, :driver_error}
    end
  end
  def set_mode(_, _) do
    {:error, :unsupported_mode}
  end

  @doc """
  Open an erlang port with the port driver.
  """
  @spec open :: pid
  def open do
    :erlang.open_port({:spawn, @driver}, [:binary])
  end

  #
  # Private API
  #

  defp command(port, message) do
    send(port, {self, {:command, message}})
  end

  defp lib_path do
    case :code.priv_dir(:hash_ring_ex) do
      {:error, :bad_name} ->
        :code.where_is_file('#{@driver}.so') |> Path.dirname
      path ->
        path
    end
  end
end
