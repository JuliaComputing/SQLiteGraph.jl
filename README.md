[![Build status](https://github.com/joshday/SQLiteGraph.jl/workflows/CI/badge.svg)](https://github.com/joshday/SQLiteGraph.jl/actions?query=workflow%3ACI+branch%3Amain)
[![Codecov](https://codecov.io/gh/joshday/SQLiteGraph.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/joshday/SQLiteGraph.jl)


<h1 align="center">SQLiteGraph</h1>

A Graph Database for Julia, built on top of [SQLite.jl](https://github.com/JuliaDatabases/SQLite.jl).

<br><br>


## Definitions

SQLiteGraph.jl uses the [Property Graph Model of the Cypher Query Language (PDF)](https://s3.amazonaws.com/artifacts.opencypher.org/openCypher9.pdf).

- A **_Node_** describes a discrete object in a domain.
- Nodes can have 0+ **_labels_** that classify what kind of node they are.
- An **_Edge_** describes a directional relationship between nodes.
- An edge must have a **_type_** that classifies the relationship.
- Both edges and nodes can have additional key-value **_properties_** that provide further information.

<br><br>

## Edges and Nodes

- Nodes and Edges have a simple representation:

```julia
struct Node
    id::Int
    labels::Vector{String}
    props::EasyConfig.Config
end

struct Edge
    source::Int
    target::Int
    type::String
    props::EasyConfig.Config
end
```

- With simple constructors:

```julia
Node(id, labels...; props...)

Edge(source_id, target_id, type; props...)
```

<br><br>

## Adding Elements to the Graph

```julia
using SQLiteGraph

db = DB()

insert!(db, Node(1, "Person", "Actor"; name="Tom Hanks"))

insert!(db, Node(2, "Movie"; title="Forest Gump"))

insert!(db, Edge(1, 2, "Acts In"; awards=["Best Actor in a Leading Role"]))
```

<br><br>

## Editing Elements

`insert!` will not replace an existing node or edge.  Instead, use `replace!`.

```julia
replace!(db, Node(2, "Movie"; title="Forest Gump", genre="Drama"))
```

<br><br>

## Simple Queries

- Use `getindex` to access elements.
- If `:` is used as an index, an iterator is returned.

```julia
db[1]  # Node(2, "Movie"; title="Forest Gump", genre="Drama")

for node in db[:]
    println(node)
end


# (Pretend the graph is populated with many more items.  The following return iterators.)

db[1, :, "Acts In"]  # All movies that Tom Hanks acts in

db[:, 2, "Acts In"]  # All actors in "Forest Gump"

db[1, 2, :]  # All relationships between "Tom Hanks" and "Forest Gump"

db[:, :, :]  # All edges
```

<br><br>

## ✨ Attribution ✨

SQLiteGraph is **STRONGLY** influenced by [https://github.com/dpapathanasiou/simple-graph](https://github.com/dpapathanasiou/simple-graph).


<br><br>

## Under the Hood Details

- Nodes and edges are saved in the `nodes` and `edges` tables, respectively.
- `nodes`
    - `id` (`INTEGER`): unique identifier of a node
    - `labels` (`TEXT`): stored as `;`-delimited (thus `;` cannot be used in a label)
    - `props` (`TEXT`): stored as `JSON3.write(props)`
- `edges`
    - `source` (`INTEGER`): id of "from" node (`nodes(id)` is a foreign key)
    - `target` (`INTEGER`): id of "to" node (`nodes(id)` is a foreign key)
    - `type` (`TEXT`): the "class" of the edge/relationship
    - `props` (`TEXT`)
