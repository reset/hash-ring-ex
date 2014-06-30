defmodule HashRing do
  use GenServer
  alias HashRing.Driver

  def start(opts \\ []) do
    case Driver.load do
      :ok ->
        {replicas, opts}  = Keyword.pop(opts, :replicas, 128)
        {hash_func, opts} = Keyword.pop(opts, :hash_func, :md5)
        GenServer.start(__MODULE__, [replicas, hash_func], opts)
      error ->
        error
    end
  end

  def start_link(opts \\ []) do
    case Driver.load do
      :ok ->
        {replicas, opts}  = Keyword.pop(opts, :replicas, 128)
        {hash_func, opts} = Keyword.pop(opts, :hash_func, :md5)
        GenServer.start_link(__MODULE__, [replicas, hash_func], opts)
      error ->
        error
    end
  end

  @spec add(pid, binary | atom) :: :ok | {:error, term}
  def add(ring, node) do
    GenServer.call(ring, {:add, node})
  end

  @spec drop(pid, binary | atom) :: :ok | {:error, term}
  def drop(ring, node) when is_atom(node), do: add(ring, to_string(node))
  def drop(ring, node) when is_binary(node) do
    GenServer.call(ring, {:drop, node})
  end

  @spec find(pid, binary | atom) :: {:ok, binary} | {:error, term}
  def find(ring, key) when is_atom(key), do: find(ring, to_string(key))
  def find(ring, key) when is_binary(key) do
    GenServer.call(ring, {:find, key})
  end

  @spec stop(pid) :: :ok
  def stop(ring) do
    GenServer.call(ring, :stop)
  end

  @spec set_mode(pid, atom) :: :ok | {:error, :term}
  def set_mode(ring, mode) do
    GenServer.call(ring, {:set_mode, mode})
  end

  #
  # GenServer callbacks
  #

  def init([replicas, hash_func]) do
    port = Driver.open
    case Driver.create(port, replicas, hash_func) do
      {:ok, index} ->
        {:ok, %{port: port, index: index}}
      error ->
        Driver.close(port)
        error
    end
  end

  def handle_call({:add, node}, _, %{port: port, index: index} = state) do
    {:reply, Driver.add(port, index, node), state}
  end

  def handle_call({:drop, node}, _, %{port: port, index: index} = state) do
    {:reply, Driver.drop(port, index, node), state}
  end

  def handle_call({:find, key}, _, %{port: port, index: index} = state) do
    {:reply, Driver.find(port, index, key), state}
  end

  def handle_call({:set_mode, mode}, _, %{port: port, index: index} = state) do
    {:reply, Driver.set_mode(port, index, mode), state}
  end

  def handle_call(:stop, _, state) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, port, _} = port_exit, %{port: port} = state) do
    {:stop, port_exit, state}
  end

  def terminate({:EXIT, port, _}, %{port: port}), do: :ok
  def terminate(_, %{port: port}) do
    Driver.close(port)
  end
end
