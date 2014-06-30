defmodule HashRing.Driver do
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

  def add(_, _, []), do: :ok
  def add(port, index, [node|rest]) do
    case add(port, index, node) do
      :ok ->
        add(port, index, rest)
      error ->
        error
    end
  end
  def add(port, index, node) when is_atom(node), do: add(port, index, to_string(node))
  def add(port, index, node) when is_binary(node) do
    command(port, <<3::size(8), index::size(32), size(node)::size(32), node::binary>>)
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

  def close(port) do
    send(port, {self, :close})
    receive do
      {port = port, :closed} ->
        :ok
    end
  end

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

  def drop(port, index, node) do
    command(port, <<4::size(8), index::size(32), size(node)::size(32), node::binary>>)
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

  def find(port, index, key) do
    command(port, <<5::size(8), index::size(32), size(key)::size(32), key::binary>>)
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

  def load do
    :erl_ddll.load_driver(lib_path, @driver)
  end

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
    case :code.priv_dir(:hash_ring) do
      {:error, :bad_name} ->
        Path.join([Path.dirname(:code.which(:hash_ring)), "..", "priv"])
      path ->
        path
    end
  end
end
