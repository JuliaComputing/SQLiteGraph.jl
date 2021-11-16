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
db[1] = (x=1, y=2) 
# properties must be `JSON3.write`-able (saved in the SQLite database as TEXT)
db[2] = (x=1, y=10)

db[1] 
# "{\"x\":1,\"y\":2}"
```

### Adding Edges 

```julia
db[1,2] = (a=1, b=2)

db[1,2]
# "{\"a\":1,\"b\":2}"
```

### `ReadAs`

- You can wrap a `DB` with `ReadAs` to enforce how you want the `TEXT` to be `JSON3.read`:

```julia
rdb = ReadAs(db, Dict{String, Int})
# ReadAs{Dict{String, Int64}}: SimpleGraphDB(":memory:") (2 nodes, 1 edges)

rdb[1]
# Dict{String, Int64} with 2 entries:
#   "x" => 1
#   "y" => 2

rdb[1,2]
# Dict{String, Int64} with 2 entries:
#   "b" => 2
#   "a" => 1
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
