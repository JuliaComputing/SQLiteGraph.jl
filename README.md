[![Build status](https://github.com/joshday/SQLiteGraph.jl/workflows/CI/badge.svg)](https://github.com/joshday/SQLiteGraph.jl/actions?query=workflow%3ACI+branch%3Amain)
[![Codecov](https://codecov.io/gh/joshday/SQLiteGraph.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/joshday/SQLiteGraph.jl)


# SQLiteGraph

A Graph Database for Julia, built on top of [SQLite.jl](https://github.com/JuliaDatabases/SQLite.jl).

## Quickstart

```julia
using SQLiteGraph

db = DB()
# SQLiteGraph.DB(":memory:") (0 nodes, 0 edges)

db[1] = Config(type="person", name="Fred")

db[2] = Config(type="person", name="Robert Ford")

db[2, 1] = Config(shot=true)
```



-  Nodes and edges must have "properties" (something that is `JSON3.write`-able), even if its `nothing`.
- Nodes must have an id (`Int`) in ascending order starting with `1`.
- Add nodes and edges with `setindex!`
  - E.g. Node 1: `db[1] = (x=1, y=2)`
  - E.g. Edge 1 → 2: `db[1, 2] = (a=3, b=4)`
- Query nodes and edges with `getindex` (as well as `find_nodes`/`find_edges`).
  - E.g. Nodes 1, 2, and 3: `db[1:3]`
  - E.g. Edges from 1 to 2 or 3: `db[1, 2:3]`
  - Returned objects are `Node` or `Edge` (or generator if multiple objects queried):
  - `Node` and `Edge` are simple structs.

  ```julia
  struct Node
      id::Int
      props::Config
  end

  struct Edge
      source::Int
      target::Int
      props::config
  end
  ```

### Creating a Graph Database

```julia
using SQLiteGraph

db = DB()
# SQLiteGraph.DB(":memory:") (0 nodes, 0 edges)
```

### Adding Nodes

```julia
# properties must be `JSON3.write`-able (saved in the SQLite database as TEXT)
db[1] = (x=1, y=2)

db[2] = (x=1, y=10)

db[1]
# Node 1
#     • y: 2
#     • x: 1
```

### Adding Edges

```julia
db[1, 2] = (a=1, b=2)

db[1, 2]
# Edge 1 → 2
#     • a: 1
#     • b: 2
```

## Iteration

```julia
for node in eachnode(db)
    println(getfield(node, :id))
end
```

### Querying Edges Based on Node ID

```julia
db[1, :]  # all outgoing edges from node 1

db[1, 2:5]  # outgoing edges from node 1 to any of nodes 2,3,4,5

db[:, 2]  # all incoming edges to node 2
```

### Querying Based on Properties

- multiple keyword args are a logical "AND"

```julia
find_nodes(db, x=1)

find_edges(db, b=2)
```

- You can also query based on Regex matches of the `TEXT` properties:

```julia
find_nodes(db, r"x")

find_edges(db, r"\"b\":2")
```

## ✨ Attribution ✨

SQLiteGraph is **STRONGLY** influenced (much has been copied verbatim) from [https://github.com/dpapathanasiou/simple-graph](https://github.com/dpapathanasiou/simple-graph).

## TODOs

- Prepare SQL into compiled `SQLite.Stmt`s.
- traversal algorithms.
