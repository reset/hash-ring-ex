defmodule HashRing do
  use GenServer

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

  def start_link(opts \\ []) do
    case :erl_ddll.load_driver(lib_path, @driver) do
      :ok ->
        {replicas, opts}  = Keyword.pop(opts, :replicas, 128)
        {hash_func, opts} = Keyword.pop(opts, :hash_func, :md5)
        GenServer.start_link(__MODULE__, [replicas, hash_func], opts)
      error ->
        error
    end
  end

  @spec add(pid, binary | atom) :: :ok | {:error, term}
  def add(ring, node) when is_atom(node), do: add(ring, to_string(node))
  def add(ring, node) when is_pid(ring) do
    GenServer.call(ring, {:add, node})
  end

  @spec drop(pid, binary | atom) :: :ok | {:error, term}
  def drop(ring, node) when is_atom(node), do: add(ring, to_string(node))
  def drop(ring, node) when is_pid(ring) do
    GenServer.call(ring, {:drop, node})
  end

  @spec find(pid, binary | atom) :: :ok | {:error, term}
  def find(ring, key) when is_atom(key), do: find(ring, to_string(key))
  def find(ring, key) when is_pid(ring) do
    GenServer.call(ring, {:find, key})
  end

  @spec stop(pid) :: :ok
  def stop(ring) when is_pid(ring) do
    GenServer.call(ring, :stop)
  end

  @spec set_mode(pid, atom) :: :ok | {:error, :term}
  def set_mode(ring, :normal) when is_pid(ring) do
    GenServer.call(ring, {:set_mode, @mode_normal})
  end

  def set_mode(ring, :memcached) when is_pid(ring) do
    GenServer.call(ring, {:set_mode, @mode_libmemcached_compat})
  end

  def set_mode(_, _) do
    {:error, :unsupported_mode}
  end

  #
  # Private API
  #

  defp lib_path do
    case :code.priv_dir(:hash_ring) do
      {:error, :bad_name} ->
        Path.join([Path.dirname(:code.which(:hash_ring)), "..", "priv"])
      path ->
        path
    end
  end

  defp create(port, replicas, hash_func) do
    command(port, <<1::size(8), replicas::size(32), hash_func::size(8)>>)
    receive do
      {port = port, {:data, <<index::size(32)>>}} ->
        {:ok, index}
    after
      @port_timeout ->
        {:error, :port_timeout}
    end
  end

  defp command(port, message) do
    send(port, {self, {:command, message}})
  end

  #
  # GenServer callbacks
  #

  def init([replicas, :md5]), do: init([replicas, @hash_function_md5])
  def init([replicas, :sha1]), do: init([replicas, @hash_function_sha1])
  def init([replicas, hash_func]) when hash_func in @hash_functions do
    port = :erlang.open_port({:spawn, @driver}, [:binary])
    case create(port, replicas, hash_func) do
      {:ok, index} ->
        {:ok, %{port: port, index: index}}
      error ->
        error
    end
  end

  def handle_call({:add, node}, _, %{port: port, index: index} = state) do
    node_size = size(node)
    command(port, <<3::size(8), index::size(32), node_size::size(32), node::binary>>)
    receive do
      {port = port, {:data, <<0::size(8)>>}} ->
        {:reply, :ok, state}
      {port = port, {:data, <<1::size(8)>>}} ->
        {:reply, {:error, :driver_error}, state}
    after
      @port_timeout ->
        {:reply, {:error, :port_timeout}, state}
    end
  end

  def handle_call({:drop, node}, _, %{port: port, index: index} = state) do
    node_size = size(node)
    command(port, <<4::size(8), index::size(32), node_size::size(32), node::binary>>)
    receive do
      {port = port, {:data, <<0::size(8)>>}} ->
        {:reply, :ok, state}
      {port = port, {:data, <<1::8>>}} ->
        {:reply, {:error, :driver_error}, state}
    after
      @port_timeout ->
        {:reply, {:error, :port_timeout}, state}
    end
  end

  def handle_call({:find, key}, _, %{port: port, index: index} = state) do
    key_size = size(key)
    send(port, {self, {:command, <<5::size(8), index::size(32), key_size::size(32), key::binary>>}})
    receive do
      {port = port, {:data, <<3::size(8)>>}} ->
        {:repy, {:error, :invalid_ring}, state}
      {port = port, {:data, <<2::size(8)>>}} ->
        {:reply, {:error, :node_not_found}}
      {port = port, {:data, <<1::size(8)>>}} ->
        {:reply, {:error, :no_nodes}, state}
      {port = port, {:data, <<node::binary>>}} ->
        {:reply, {:ok, node}, state}
    end
  end

  def handle_call({:set_mode, mode}, _, %{port: port, index: index} = state) do
    command(port, <<6::size(8), index::size(32), mode::size(8)>>)
    receive do
      {port = port, {:data, <<0::size(8)>>}} ->
        {:reply, :ok, state}
      {port = port, {:data, <<1::size(8)>>}} ->
        {:reply, {:error, :driver_error}, state}
    end
  end

  def handle_call(:stop, _, state) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, port, _} = port_exit, %{port: port} = state) do
    {:stop, port_exit, state}
  end

  def terminate({:EXIT, port, _}, %{port: port}), do: :ok
  def terminate(_, %{port: port}) do
    send(port, {self, :close})
    receive do
      {port = port, :closed} ->
        :ok
    end
  end
end
