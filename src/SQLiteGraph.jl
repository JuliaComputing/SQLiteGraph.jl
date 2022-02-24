module SQLiteGraph

using SQLite: SQLite
import DBInterface: execute
using JSON3: JSON3
using EasyConfig

export DB, Node, Edge

#-----------------------------------------------------------------------------# utils
function single_result_execute(db, stmt, args...)
    ex = execute(db, stmt, args...)
    isempty(ex) ? nothing : values(first(ex))[1]
end

function print_props(io::IO, o::Config)
    for (k,v) in pairs(o)
        printstyled(io, "\n    • $k: ", color=:light_black)
        print(IOContext(io, :compat=>true), v)
    end
end


#-----------------------------------------------------------------------------# Model
# Nodes describe entities (discrete objects) of a domain.
# Nodes can have zero or more labels to define (classify) what kind of nodes they are.
# Nodes and relationships can have properties (key-value pairs), which further describe them.

# Relationships describes a connection between a source node and a target node.
# Relationships always has a direction (one direction).
# Relationships must have a type (one type) to define (classify) what type of relationship they are.

# Nouns-nodes, Adjectives-properties, Verbs-relationship, Adverbs-properties on relationship

# Property Graph Model on page 4
# https://s3.amazonaws.com/artifacts.opencypher.org/openCypher9.pdf

struct Node
    id::Int
    labels::Vector{String}
    props::Config
end
Node(id::Int, labels::String...; props...) = Node(id, collect(labels), Config(props))
Node(row::SQLite.Row) = Node(row.id, split(row.labels, ';'), JSON3.read(row.props, Config))
function Base.show(io::IO, o::Node)
    printstyled(io, "Node(", color=:light_cyan)
    printstyled(io, join(repr.(o.labels), ", "), color=:light_yellow)
    printstyled(io, ", ", o.id, color=:light_black)
    printstyled(io, ")", color=:light_cyan)
    if isempty(o.props)
        printstyled(io, " with no props", color=:light_black)
    else
        printstyled(io, " with props: ", color=:light_black)
        printstyled(io, join(keys(o.props), ", "), color=:light_green)
    end
end
args(n::Node) = (n.id, join(n.labels, ';'), JSON3.write(n.props))


struct Edge
    source::Int
    target::Int
    type::String
    props::Config
end
Edge(src::Int, tgt::Int, type::String; props...) = Edge(src, tgt, type, Config(props))
Edge(row::SQLite.Row) = Edge(row.source, row.target, row.type, JSON3.read(row.props, Config))
function Base.show(io::IO, o::Edge)
    printstyled(io, "Edge(", color=:light_cyan)
    printstyled(io, repr(o.type), color=:light_yellow)
    printstyled(io, ", $(o.source) → $(o.target)", color=:light_black)
    printstyled(io, ")", color=:light_cyan)
    if isempty(o.props)
        printstyled(io, " with no props", color=:light_black)
    else
        printstyled(io, " with props: ", color=:light_black)
        printstyled(io, join(keys(o.props), ", "), color=:light_green)
    end
end
args(e::Edge) = (e.source, e.target, join(e.type, ';'), JSON3.write(e.props))

#-----------------------------------------------------------------------------# DB
struct DB
    sqlitedb::SQLite.DB

    function DB(file::String = ":memory:")
        db = SQLite.DB(file)
        foreach(x -> execute(db, x), [
            # nodes
            "CREATE TABLE IF NOT EXISTS nodes (
                id INTEGER NOT NULL UNIQUE PRIMARY KEY,
                labels TEXT,
                props TEXT,
                UNIQUE(id) ON CONFLICT REPLACE
            );",
            "CREATE INDEX IF NOT EXISTS id_idx ON nodes(id);",
            "CREATE INDEX IF NOT EXISTS labels_idx ON nodes(labels);",

            # edges
            "CREATE TABLE IF NOT EXISTS edges (
                source INTEGER NOT NULL,
                target INTEGER NOT NULL,
                type TEXT NOT NULL,
                props TEXT,
                FOREIGN KEY(source) REFERENCES nodes(id),
                FOREIGN KEY(target) REFERENCES nodes(id)
            );",
            "CREATE INDEX IF NOT EXISTS source_idx ON edges(source);",
            "CREATE INDEX IF NOT EXISTS target_idx ON edges(target);",
            "CREATE INDEX IF NOT EXISTS type_idx ON edges(type);",
        ])
        new(db)
    end
end
function Base.show(io::IO, db::DB)
    print(io, "SQLiteGraph.DB(\"$(db.sqlitedb.file)\") ($(n_nodes(db)) nodes, $(n_edges(db)) edges)")
end

execute(db::DB, args...; kw...) = execute(db.sqlitedb, args...; kw...)

n_nodes(db::DB) = single_result_execute(db, "SELECT Count(*) FROM nodes")
n_edges(db::DB) = single_result_execute(db, "SELECT Count(*) FROM edges")

Base.length(db::DB) = n_nodes(db)
Base.size(db::DB) = (n_nodes=n_nodes(db), n_edges=n_edges(db))

#-----------------------------------------------------------------------------# nodes
function Base.getindex(db::DB, id::Integer)
    res = execute(db, "SELECT * FROM nodes WHERE id = ?", (id,))
    isempty(res) ? throw(BoundsError(db, id)) : Node(first(res))
end

function Base.push!(db::DB, node::Node)
    res = execute(db, "SELECT * FROM nodes WHERE id=?", (node.id,))
    isempty(res) ?
        execute(db, "INSERT INTO nodes VALUES(?, ?, json(?))", args(node)) :
        error("Node with id=$(node.id) already exists in graph.  Use `insert!` to overwrite.")
    db
end
function Base.insert!(db::DB, node::Node)
    execute(db, "INSERT INTO nodes VALUES(?, ?, json(?)) ON CONFLICT(id) DO UPDATE SET labels=excluded.labels, props=excluded.props", args(node))
    db
end




# #-----------------------------------------------------------------------------# get/set nodes
# function Base.setindex!(db::DB, props, id::Integer)
#     id ≤ length(db) + 1 || error("Cannot add node ID=$id to DB with $(length(db)) nodes.  IDs must be added sequentially.")
#     execute(db, "INSERT INTO nodes VALUES(?, json(?))", (id, JSON3.write(props)))
#     db
# end
# function Base.getindex(db::DB, id::Integer)
#     res = single_result_execute(db, "SELECT props FROM nodes WHERE id = ?", (id,))
#     isnothing(res) ? throw(BoundsError(db, id)) : Node(id, res)
# end
# Base.getindex(db::DB, ids::AbstractArray{<:Integer}) = (getindex(db, id) for id in ids)
# function Base.getindex(db::DB, ::Colon)
#     res = execute(db, "SELECT props from nodes")
#     (Node(i, row.props) for (i,row) in enumerate(res))
# end
# function Base.deleteat!(db::DB, id::Integer)
#     execute(db, "DELETE FROM nodes WHERE id = ?", (id,))
#     execute(db, "DELETE FROM edges WHERE source = ? OR target = ?", (id, id))
#     db
# end

# #-----------------------------------------------------------------------------# get/set edges
# function Base.setindex!(db::DB, props, i::Integer, j::Integer)
#     execute(db, "INSERT INTO edges VALUES(?, ?, json(?))", (i, j, JSON3.write(props)))
#     db
# end
# function Base.getindex(db::DB, i::Integer, j::Integer)
#     res = single_result_execute(db, "SELECT props FROM edges WHERE source = ? AND target = ? ", (i,j))
#     isnothing(res) ? res : Edge(i, j, res)
# end
# Base.getindex(db::DB, i::Integer, js::AbstractArray{<:Integer}) = filter!(!isnothing, getindex.(db, i, js))
# Base.getindex(db::DB, is::AbstractArray{<:Integer}, j::Integer) = filter!(!isnothing, getindex.(db, is, j))
# function Base.getindex(db::DB, is::AbstractArray{<:Integer}, js::AbstractArray{<:Integer})
#     res = vcat((getindex(db, i, js) for i in is)...)
#     isempty(res) ? nothing : res
# end
# function Base.getindex(db::DB, i::Integer, ::Colon)
#     res = execute(db, "SELECT * FROM edges WHERE source=?", (i,))
#     isempty(res) ? nothing : (Edge(row...) for row in res)
# end
# function Base.getindex(db::DB, ::Colon, j::Integer)
#     res = execute(db, "SELECT * FROM edges WHERE target=?", (j,))
#     isempty(res) ? nothing : (Edge(row...) for row in res)
# end
# function Base.getindex(db::DB, ::Colon, ::Colon)
#     res = execute(db, "SELECT * from edges")
#     isempty(res) ? nothing : (Edge(row...) for row in res)
# end
# Base.getindex(db::DB, is::AbstractArray{<:Integer}, ::Colon) = filter!(!isnothing, getindex.(db, is, :))
# Base.getindex(db::DB, ::Colon, js::AbstractArray{<:Integer}) = filter!(!isnothing, getindex.(db, :, js))

# function Base.deleteat!(db::DB, i::Integer, j::Integer)
#     execute(db, "DELETE FROM edges WHERE source = ? AND target = ?", (i, j))
#     db
# end

# #-----------------------------------------------------------------------------# interfaces
# Base.length(db::DB) = n_nodes(db)
# Base.size(db::DB) = (nodes=n_nodes(db), edges=n_edges(db))
# Base.lastindex(db::DB) = length(db)
# Base.axes(db::DB, i) = size(db)[i]

# Broadcast.broadcastable(db::DB) = Ref(db)

# #-----------------------------------------------------------------------------# iterators
# eachnode(db::DB) = (db[i] for i in 1:length(db))
# eachedge(db::DB) = (Edge(row...) for row in execute(db, "SELECT * from edges"))

end
