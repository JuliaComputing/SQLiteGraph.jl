[![Build status](https://github.com/joshday/SQLiteGraph.jl/workflows/CI/badge.svg)](https://github.com/joshday/SQLiteGraph.jl/actions?query=workflow%3ACI+branch%3Amain)
[![Codecov](https://codecov.io/gh/joshday/SQLiteGraph.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/joshday/SQLiteGraph.jl)


<h1 align="center">SQLiteGraph<h1>

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

insert!(db, Edge(1, 2, "Acts In"))
```

<br><br>

## Editing Elements

`insert!` will not replace an existing node or edge.  Instead, use `replace!`.

```julia
replace!(db, Node(2, "Movie"; title="Forest Gump", genre="Drama"))
```

<br><br>

## ✨ Attribution ✨

SQLiteGraph is **STRONGLY** influenced (much has been copied verbatim) from [https://github.com/dpapathanasiou/simple-graph](https://github.com/dpapathanasiou/simple-graph).
