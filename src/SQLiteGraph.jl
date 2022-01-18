module SQLiteGraph

using SQLite: SQLite
import DBInterface: execute
using JSON3: JSON3

export DB, Node, Edge, find_nodes, find_edges

#-----------------------------------------------------------------------------# utils
read_sql(fn::String) = read(joinpath(@__DIR__, "sql", fn), String)

function single_result_execute(db, stmt, args...)
    ex = execute(db, stmt, args...)
    isempty(ex) ? nothing : values(first(ex))[1]
end

#-----------------------------------------------------------------------------# Node
struct Node{T}
    id::Int
    props::T
    Node(id::Integer, props=nothing) = new{typeof(props)}(id, props)
end

function Base.show(io::IO, o::Node)
    print(io, "Node($(o.id)) with props: ")
    print(io, o.props)
end

#-----------------------------------------------------------------------------# Edge
struct Edge{T}
    source::Int
    target::Int
    props::T
    function Edge(source::Integer, target::Integer, props=nothing)
        new{typeof(props)}(source, target, props)
    end
end
Edge(T::DataType, e::Edge{<:AbstractString}) = Edge(e.source, e.target, JSON3.read(e.props, T))
Edge(e::Edge{<:AbstractString}, T::DataType) = Edge(e.source, e.target, JSON3.read(e.props, T))
function Base.show(io::IO, o::Edge)
    print(io, "Edge($(o.source) → $(o.target)) with props: ")
    print(io, o.props)
end


#-----------------------------------------------------------------------------# DB
"""
    DB(file = ":memory", T = String)

Create a graph database (in memory by default).
- Node and edge properties are saved in the database as `TEXT` (see [https://www.sqlite.org/datatype3.html](https://www.sqlite.org/datatype3.html)) via `JSON3.write(props)`.
- Node and edge properties will be interpreted as `T` in Julia: `JSON3.read(props, T)`

# Interal Table Structure

- `nodes`
  - `id INTEGER NOT NULL UNIQUE`
  - `props TEXT` (via JSON3.write)
- `edges`
  - `source INTEGER`
  - `target INTEGER`
  - `props TEXT` (via JSON3.write)

# Examples

    db = DB()

    db[1] = (x=1, y=2)  # node 1

    db[2] = (x=1, y=3)  # node 2

    db[1,2] = (z = 4)   # edge from 1 → 2
"""
struct DB{T}
    sqlitedb::SQLite.DB

    function DB(file::String = ":memory:", T::Type = String)
        db = SQLite.DB(file)
        SQLite.@register db SQLite.regexp
        statements = [
            "CREATE TABLE IF NOT EXISTS nodes (
                id INTEGER NOT NULL UNIQUE,
                props TEXT,
                UNIQUE(id) ON CONFLICT REPLACE
            );",
            "CREATE INDEX IF NOT EXISTS id_idx ON nodes(id);",
            "CREATE TABLE IF NOT EXISTS edges (
                source INTEGER,
                target INTEGER,
                props  TEXT,
                UNIQUE(source, target) ON CONFLICT REPLACE,
                FOREIGN KEY(source) REFERENCES nodes(id),
                FOREIGN KEY(target) REFERENCES nodes(id)
            );",
            "CREATE INDEX IF NOT EXISTS source_idx ON edges(source);",
            "CREATE INDEX IF NOT EXISTS target_idx ON edges(target);"
        ]
        # workaround because sqlite won't run multiple statements at once
        map(statements) do x
            execute(db, x)
        end
        new{T}(db)
    end
end
DB(T::Type, file::String = ":memory:") = DB(file, T)
DB(T::Type, db::DB) = DB(db.sqlitedb, T)
DB(db::DB, T::Type) = DB(T, db)
function Base.show(io::IO, db::DB{T}) where {T}
    print(io, "SQLiteGraph.DB{$T}(\"$(db.sqlitedb.file)\") ($(n_nodes(db)) nodes, $(n_edges(db)) edges)")
end

execute(db::DB, args...; kw...) = execute(db.sqlitedb, args...; kw...)

n_nodes(db::DB) = single_result_execute(db, "SELECT Count(*) FROM nodes")
n_edges(db::DB) = single_result_execute(db, "SELECT Count(*) FROM edges")

init!(db::DB, n) = (foreach(id -> setindex!(db, nothing, id), 1:n); db)


#-----------------------------------------------------------------------------# interfaces
Base.length(db::DB) = n_nodes(db)
Base.size(db::DB) = (nodes=n_nodes(db), edges=n_edges(db))
Base.lastindex(db::DB) = length(db)
Base.axes(db::DB, i) = size(db)[i]

Broadcast.broadcastable(db::DB) = Ref(db)

function Base.iterate(db::DB, state = (length(db), 1))
    state[2] > state[1] && return nothing
    res = single_result_execute(db, "SELECT props FROM nodes WHERE id = ?", (state[2],))
    Node(state[2], res), (state[1], state[2] + 1)
end

# #-----------------------------------------------------------------------------# ReadAs
# struct ReadAs{T}
#     db::DB
# end
# ReadAs(db::DB, T::DataType=Dict{String,Any}) = ReadAs{T}(db)
# Base.show(io::IO, r::ReadAs{T}) where {T} = (print(io, "ReadAs{$T}: "); print(io, r.db))
# Base.setindex!(r::ReadAs, args...) = setindex!(r.db, args...)
# function Base.getindex(r::ReadAs{T}, args...) where {T}
#     res=r.db[args...]; isnothing(res) ? res : JSON3.read.(res, T)
# end

# _transform(node::Node{String}, T) = Node(node.id, JSON)
# Base.deleteat!(r::ReadAs, args...) = deleteat!(r.db, args...)

#-----------------------------------------------------------------------------# nodes
function Base.setindex!(db::DB, props, id::Integer)
    id ≤ length(db) + 1 || error("Cannot add node ID=$id to DB with $(length(db)) nodes.  IDs must be added sequentially.")
    execute(db, "INSERT INTO nodes VALUES(?, json(?))", (id, JSON3.write(props)))
    db
end
function Base.getindex(db::DB, id::Integer)
    res = single_result_execute(db, "SELECT props FROM nodes WHERE id = ?", (id,))
    isnothing(res) ? throw(BoundsError(db, id)) : Node(id, res)
end
Base.getindex(db::DB, ids::AbstractArray{<:Integer}) = getindex.(db, ids)
function Base.getindex(db::DB, ::Colon)
    res = execute(db, "SELECT props from nodes")
    (Node(i,row.props) for (i,row) in enumerate(res))
end
function Base.deleteat!(db::DB, id::Integer)
    execute(db, "DELETE FROM nodes WHERE id = ?", (id,))
    execute(db, "DELETE FROM edges WHERE source = ? OR target = ?", (id, id))
    db
end
#-----------------------------------------------------------------------------# find_nodes
function find_nodes(db::DB; kw...)
    param = join(map(collect(kw)) do kw
        k, v = kw
        "json_extract(props, '\$.$k') = $v"
    end, " AND ")

    res = execute(db, "SELECT * FROM nodes WHERE $param")
    isempty(res) ? nothing : (Node(row...) for row in res)
end
function find_nodes(db::DB, r::Regex)
    res = execute(db, "SELECT * FROM nodes WHERE props REGEXP ?", (r.pattern,))
    isempty(res) ? nothing : (Node(row...) for row in res)
end


#-----------------------------------------------------------------------------# edges
function Base.setindex!(db::DB, props, i::Integer, j::Integer)
    execute(db, "INSERT INTO edges VALUES(?, ?, json(?))", (i, j, JSON3.write(props)))
    db
end
function Base.getindex(db::DB, i::Integer, j::Integer)
    res = single_result_execute(db, "SELECT props FROM edges WHERE source = ? AND target = ? ", (i,j))
    isnothing(res) ? res : Edge(i, j, res)
end
Base.getindex(db::DB, i::Integer, js::AbstractArray{<:Integer}) = filter!(!isnothing, getindex.(db, i, js))
Base.getindex(db::DB, is::AbstractArray{<:Integer}, j::Integer) = filter!(!isnothing, getindex.(db, is, j))
function Base.getindex(db::DB, is::AbstractArray{<:Integer}, js::AbstractArray{<:Integer})
    res = vcat((getindex(db, i, js) for i in is)...)
    isempty(res) ? nothing : res
end
function Base.getindex(db::DB, i::Integer, ::Colon)
    res = execute(db, "SELECT * FROM edges WHERE source=?", (i,))
    isempty(res) ? nothing : (Edge(row...) for row in res)
end
function Base.getindex(db::DB, ::Colon, j::Integer)
    res = execute(db, "SELECT * FROM edges WHERE target=?", (j,))
    isempty(res) ? nothing : (Edge(row...) for row in res)
end
function Base.getindex(db::DB, ::Colon, ::Colon)
    res = execute(db, "SELECT * from edges")
    isempty(res) ? nothing : (Edge(row...) for row in res)
end
Base.getindex(db::DB, is::AbstractArray{<:Integer}, ::Colon) = filter!(!isnothing, getindex.(db, is, :))
Base.getindex(db::DB, ::Colon, js::AbstractArray{<:Integer}) = filter!(!isnothing, getindex.(db, :, js))

function Base.deleteat!(db::DB, i::Integer, j::Integer)
    execute(db, "DELETE FROM edges WHERE source = ? AND target = ?", (i, j))
    db
end

#-----------------------------------------------------------------------------# find_edges
function find_edges(db::DB; kw...)
    param = join(map(collect(kw)) do kw
        k, v = kw
        "json_extract(props, '\$.$k') = $v"
    end, " AND ")

    res = execute(db, "SELECT * FROM edges WHERE $param")
    isempty(res) ? nothing : (Edge(row...) for row in res)
end
function find_edges(db::DB, r::Regex)
    res = execute(db, "SELECT * FROM edges WHERE props REGEXP ?", (r.pattern,))
    isempty(res) ? nothing : (Edge(row...) for row in res)
end

end
