module SQLiteGraph

using SQLite: SQLite
import DBInterface: execute
using JSON3: JSON3
using EasyConfig

export DB, Node, Edge

#-----------------------------------------------------------------------------# utils
function single_result_execute(db, stmt, args...)
    ex = execute(db, stmt, args...)
    isempty(ex) ? nothing : first(first(ex))
end

function print_props(io::IO, o::Config)
    for (k,v) in pairs(o)
        printstyled(io, "\n    • $k: ", color=:light_black)
        print(IOContext(io, :compat=>true), v)
    end
end


#-----------------------------------------------------------------------------# Model
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
Base.:(==)(a::Node, b::Node) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(Node))


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
args(e::Edge) = (e.source, e.target, e.type, JSON3.write(e.props))
Base.:(==)(a::Edge, b::Edge) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(Edge))


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
                FOREIGN KEY(target) REFERENCES nodes(id),
                UNIQUE(source, target, type)
            );",
            "CREATE INDEX IF NOT EXISTS source_idx ON edges(source);",
            "CREATE INDEX IF NOT EXISTS target_idx ON edges(target);",
            "CREATE INDEX IF NOT EXISTS type_idx ON edges(type);",
            "CREATE INDEX IF NOT EXISTS source_target_type_idx ON edges(source, target, type);"
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
function Base.push!(db::DB, node::Node; upsert=false)
    upsert ?
        execute(db, "INSERT INTO nodes VALUES(?, ?, json(?)) ON CONFLICT(id) DO UPDATE SET labels=excluded.labels, props=excluded.props", args(node)) :
        execute(db, "INSERT INTO nodes VALUES(?, ?, json(?))", args(node))
    db
end

function Base.getindex(db::DB, id::Integer)
    res = execute(db, "SELECT * FROM nodes WHERE id = ?", (id,))
    isempty(res) ? error("Node $id does not exist.") : Node(first(res))
end
function Base.getindex(db::DB, ::Colon)
    res = execute(db, "SELECT * FROM nodes")
    isempty(res) ? error("No nodes exist yet.") : (Node(row) for row in res)
end


#-----------------------------------------------------------------------------# edges
function Base.push!(db::DB, edge::Edge; upsert=false)
    i, j = edge.source, edge.target
    check = single_result_execute(db, "SELECT COUNT(*) FROM nodes WHERE id=? OR id=?", (i, j))
    (isnothing(check) || check < 2) && error("Nodes $i and $j must exist in order for an edge to connect them.")
    upsert ?
        execute(db, "INSERT INTO edges VALUES(?, ?, ?, json(?)) ON CONFLICT(source,target,type) DO UPDATE SET props=excluded.props", args(edge)) :
        execute(db, "INSERT INTO edges VALUES(?, ?, ?, json(?))", args(edge))
    db
end

function Base.getindex(db::DB, i::Integer, j::Integer, type::AbstractString)
    res = execute(db, "SELECT * FROM edges WHERE source=? AND target=? AND type=?", (i,j,type))
    isempty(res) ? error("Edge $i → $type → $j does not exist.") : Edge(first(res))
end
function Base.getindex(db::DB, i::Integer, j::Integer, ::Colon = Colon())
    res = execute(db, "SELECT * FROM edges WHERE source=? AND target=?", (i, j))
    isempty(res) ? error("No edges connect nodes $i → $j.") : (Edge(row) for row in res)
end

function Base.getindex(db::DB, ::Colon, j::Integer, type::AbstractString)
    res = execute(db, "SELECT * FROM edges WHERE target=? AND type=?", (j, type))
    isempty(res) ? error("No incoming edges $type → $j") : (Edge(row) for row in res)
end
function Base.getindex(db::DB, i::Colon, j::Integer, ::Colon=Colon())
    res = execute(db, "SELECT * FROM edges WHERE target=?", (j,))
    isempty(res) ? error("No incoming edges into node $j") : (Edge(row) for row in res)
end

function Base.getindex(db::DB, i::Integer, ::Colon, type::AbstractString)
    res = execute(db, "SELECT * FROM edges WHERE source=? AND type=?", (i,type))
    isempty(res) ? error("No outgoing edges $type → $i") : (Edge(row) for row in res)
end
function Base.getindex(db::DB, i::Integer, ::Colon, ::Colon=Colon())
    res = execute(db, "SELECT * FROM edges WHERE source=?", (i,))
    isempty(res) ? error("No outgoing edges from node $i") : (Edge(row) for row in res)
end


#-----------------------------------------------------------------------------# interfaces
Base.length(db::DB) = n_nodes(db)
Base.size(db::DB) = (nodes=n_nodes(db), edges=n_edges(db))
Base.lastindex(db::DB) = length(db)
Base.axes(db::DB, i) = size(db)[i]

Broadcast.broadcastable(db::DB) = Ref(db)

end
