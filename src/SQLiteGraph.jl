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
    for (i,(k,v)) in enumerate(pairs(o))
        print(io, k, '=', repr(v))
        i == length(o) || print(io, ", ")
    end
end


#-----------------------------------------------------------------------------# Model
struct Node
    id::Int
    labels::Vector{String}
    props::Config
end
Node(id::Int, labels::String...; props...) = Node(id, collect(labels), Config(props))
Node(row::SQLite.Row) = Node(row.id, split(row.labels, ';', keepempty=false), JSON3.read(row.props, Config))
function Base.show(io::IO, o::Node)
    print(io, "Node($(o.id)")
    !isempty(o.labels) && print(io, ", ", join(repr.(o.labels), ", "))
    !isempty(o.props) && print(io, "; "); print_props(io, o.props)
    print(io, ')')
end
args(n::Node) = (n.id, isempty(n.labels) ? "" : join(n.labels, ';'), JSON3.write(n.props))



struct Edge
    source::Int
    target::Int
    type::String
    props::Config
end
Edge(src::Int, tgt::Int, type::String; props...) = Edge(src, tgt, type, Config(props))
Edge(row::SQLite.Row) = Edge(row.source, row.target, row.type, JSON3.read(row.props, Config))
function Base.show(io::IO, o::Edge)
    print(io, "Edge($(o.source), $(o.target), ", repr(o.type))
    !isempty(o.props) && print(io, "; "); print_props(io, o.props)
    print(io, ')')
end
args(e::Edge) = (e.source, e.target, e.type, JSON3.write(e.props))


#-----------------------------------------------------------------------------# Base methods
Base.:(==)(a::Node, b::Node) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(Node))
Base.:(==)(a::Edge, b::Edge) = all(getfield(a,f) == getfield(b,f) for f in fieldnames(Edge))

Base.pairs(o::T) where {T<: Union{Node, Edge}} = (f => getfield(o,f) for f in fieldnames(T))

Base.NamedTuple(o::Union{Node,Edge}) = NamedTuple(pairs(o))



#-----------------------------------------------------------------------------# DB
struct DB
    sqlitedb::SQLite.DB

    function DB(file::String = ":memory:")
        db = SQLite.DB(file)
        foreach(x -> execute(db, x), [
            "PRAGMA foreign_keys = ON;",
            # nodes
            "CREATE TABLE IF NOT EXISTS nodes (
                id INTEGER NOT NULL UNIQUE PRIMARY KEY,
                labels TEXT NOT NULL,
                props TEXT NOT NULL
            );",
            # edges
            "CREATE TABLE IF NOT EXISTS edges (
                source INTEGER NOT NULL REFERENCES nodes(id),
                target INTEGER NOT NULL REFERENCES nodes(id),
                type TEXT NOT NULL,
                props TEXT NOT NULL,
                PRIMARY KEY (source, target, type)
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
Base.size(db::DB) = (nodes=n_nodes(db), edges=n_edges(db))
Base.lastindex(db::DB) = length(db)
Base.axes(db::DB, i) = size(db)[i]

Broadcast.broadcastable(db::DB) = Ref(db)

#-----------------------------------------------------------------------------# insert!
function Base.insert!(db::DB, node::Node)
    execute(db, "INSERT INTO nodes VALUES(?, ?, json(?))", args(node))
    db
end
function Base.insert!(db::DB, edge::Edge)
    execute(db, "INSERT INTO edges VALUES(?, ?, ?, json(?))", args(edge))
    db
end

#-----------------------------------------------------------------------------# replace!
function Base.replace!(db::DB, node::Node)
    execute(db, "INSERT INTO nodes VALUES(?, ?, json(?)) ON CONFLICT(id) DO UPDATE SET labels=excluded.labels, props=excluded.props", args(node))
    db
end
function Base.replace!(db::DB, edge::Edge)
    execute(db, "INSERT INTO edges VALUES(?, ?, ?, json(?)) ON CONFLICT(source,target,type) DO UPDATE SET props=excluded.props", args(edge))
    db
end

#-----------------------------------------------------------------------------# query
function query(db::DB, select::String, from::String, whr::String, args=nothing)
    stmt = "SELECT $select FROM $from WHERE $whr"
    # @info stmt
    res = isnothing(args) ? execute(db, stmt) : execute(db, stmt, args)
    if isempty(res)
        error("No $from found where: $whr")
    else
        return res
    end
end

#-----------------------------------------------------------------------------# getindex (Node)
Base.getindex(db::DB, i::Integer) = Node(first(query(db, "*", "nodes", "id=$i")))
Base.getindex(db::DB, ::Colon) = (Node(row) for row in query(db, "*", "nodes", "TRUE"))

#-----------------------------------------------------------------------------# getindex (Edge)
# all specified
function Base.getindex(db::DB, i::Integer, j::Integer, type::AbstractString)
    Edge(first(query(db, "*", "edges", "source=$i AND target=$j AND type LIKE '$type'")))
end

# one colon
function Base.getindex(db::DB, i::Integer, j::Integer, ::Colon)
    (Edge(row) for row in query(db, "*", "edges", "source=$i AND target=$j"))
end
function Base.getindex(db::DB, i::Integer, ::Colon, type::AbstractString)
    (Edge(row) for row in query(db, "*", "edges", "source=$i AND type LIKE '$type'"))
end
function Base.getindex(db::DB, ::Colon, j::Integer, type::AbstractString)
    (Edge(row) for row in query(db, "*", "edges", "target=$j AND type LIKE '$type'"))
end

# two colons
function Base.getindex(db::DB, i::Integer, ::Colon, ::Colon)
    (Edge(row) for row in query(db, "*", "edges", "source=$i"))
end
function Base.getindex(db::DB, i::Colon, j::Integer, ::Colon)
    (Edge(row) for row in query(db, "*", "edges", "target=$j"))
end
function Base.getindex(db::DB, ::Colon, ::Colon, type::AbstractString)
    (Edge(row) for row in query(db, "*", "edges", "type LIKE '$type'"))
end

# all colons
Base.getindex(db::DB, ::Colon, ::Colon, ::Colon) = (Edge(row) for row in query(db,"*", "edges", "TRUE"))

#-----------------------------------------------------------------------------# adjacency_matrix
function adjacency_matrix(db::DB)
    n = n_nodes(db)
    out = falses(n, n)
    src, tgt = Int[], Int[]
    for row in execute(db, "SELECT DISTINCT source, target FROM edges;")
        push!(src, row.source)
        push!(tgt, row.target)
    end
    for (i,j) in zip(src, tgt)
        out[i,j] = true
    end
    out
end

end
