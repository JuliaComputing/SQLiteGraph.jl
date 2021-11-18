# SQLiteGraph

A Graph Database for Julia, built on top of [SQLite.jl](https://github.com/JuliaDatabases/SQLite.jl).

## Quickstart

- *Nodes* and *Edges* must have "properties", even if `nothing`.
- The types returned by `getindex` (`Node`/`Edge`) have a `props` field that contains the JSON String.
  - You can read it as whatever type you wish with `JSON3.read(node.props, T)`


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
# "{\"x\":1,\"y\":2}"
```

### Adding Edges 

```julia
db[1, 2] = (a=1, b=2)

db[1, 2]
# "{\"a\":1,\"b\":2}"
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

## Attribution

SQLiteGraph is **STRONGLY** influenced (much has been copied verbatim) from [https://github.com/dpapathanasiou/simple-graph](https://github.com/dpapathanasiou/simple-graph).  

## TODOs

- Prepare SQL into compiled `SQLite.Stmt`s.
- traversal algorithms.
