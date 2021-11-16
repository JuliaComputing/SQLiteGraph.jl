# SQLiteGraph

A Graph Database for Julia, built on top of [SQLite.jl](https://github.com/JuliaDatabases/SQLite.jl).

## Quickstart

- *Nodes* must have "properties", even if `nothing`.
- *Edges* must have "properties", even if `nothing`.


### Creating a Graph Database

```julia
using SQLiteGraph

db = DB()
# SimpleGraphDB(":memory:") (0 nodes, 0 edges)
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

db[:, 1]  # all incoming edges to node 1
```

### Querying Based on Properties

- multiple keyword args are a logical "AND"

```julia
SQLiteGraph.findnodes(db, x=1)

SQLiteGraph.findedges(db, b=2)
```

## Attribution

SQLiteGraph is **STRONGLY** influenced (much has been copied verbatim) from [https://github.com/dpapathanasiou/simple-graph](https://github.com/dpapathanasiou/simple-graph).  

The differences here are minor, opinionated changes made by `@joshday`:

- Node IDs are `Int`: 1, 2, 3...
- Both `nodes` and `edges` tables have field `props`

## TODOs

- Prepare SQL into compiled `SQLite.Stmt`s.
- querying
- traverse
