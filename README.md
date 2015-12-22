# HashRing

[![Build Status](https://travis-ci.org/reset/hash-ring-ex.png?branch=master)](https://travis-ci.org/reset/hash-ring-ex)

A consistent hash-ring implemention leveraging the excellent [C hash-ring lib](https://github.com/chrismoos/hash-ring) by [Chris Moos](https://github.com/chrismoos) for Elixir.

## Requirements

* Elixir 1.1.0 or newer

## Installation

Add HashRing as a dependency in your `mix.exs` file

```elixir
defp deps do
  [
    {hash_ring_ex: "~> 1.0"}
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

## Usage

Start or supervise a new HashRing with `HashRing.start_link/1` or `HashRing.start/1` and add some nodes

```elixir
{:ok, pid} = HashRing.start_link
:ok = HashRing.add(pid, "first_node")
:ok = HashRing.add(pid, "second_node")
```

Then find the appropriate node for your key

```elixir
{:ok, "first_node"} = HashRing.find(pid, "my_key")
```

Nodes can also be easily dropped

```elixir
:ok = HashRing.drop(pid, "first_node")
{:ok, "second_node"} = HashRing.find(pid, "my_key")
```

### Configuring

Started rings will use an MD5 hash function by default. In tests MD5 is on average about 25% faster than sha1. The hashing function to use can be specified as an option sent to `start_link/1 or `start/1`

```elixir
{:ok, md5}  = HashRing.start_link(hash_func: :md5)
{:ok, sha1} = HashRing.start_link(hash_func: :sha1)
```

The number of replicas can be configured, too (default: 128)

```elixir
{:ok, pid} = HashRing.start_link(replicas: 5)
```

And the standard GenServer options can be passed in, too

```elixir
{:ok, pid} = HashRing.start_link(name: :my_hash_ring)
```

## Authors

Jamie Winsor (<jamie@vialstudios.com>)
