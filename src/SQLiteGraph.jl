module SQLiteGraph

using SQLite: SQLite
import DBInterface: execute
using JSON3: JSON3
using EasyConfig

export DB, Node, Edge, find_nodes, find_edges

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

struct Node
    id::Int
    labels::Vector{String}
    props::Config
end
Node(id::Int, labels::String...; props...) = Node(id, collect(labels), Config(props))
function Base.show(io::IO, o::Node)
    print(io, "Node($(join(o.labels, ", "))) | $(o.id) | nprops=$(length(o.props))")
end


struct Relationship
    source_id::Int
    target_id::Int
    type::String
    props::Config
end
Relationship(src::Int, tgt::Int, type::String; props...) = Relationship(src, tgt, type, Config(props))
function Base.show(io::IO, o::Relationship)
    print(io, "Relationship($(o.type)) | $(o.source_id) → $(o.target_id) | nprops=$(length(o.props))")
end




# #-----------------------------------------------------------------------------# Node
# struct Node
#     id::Int
#     props::Config
# end
# Node(id::Integer; props...) = Node(id, Config(props))
# Node(id::Integer, props::String) = Node(id, JSON3.read(props, Config))
# function Base.show(io::IO, o::Node)
#     props = getfield(o, :props)
#     printstyled(io, "Node $(getfield(o, :id))", color=:light_cyan)
#     delete_empty!(props)
#     print_props(io, props)
# end
# Base.getproperty(o::Node, x::Symbol) = getfield(o, :props)[x]
# Base.setproperty!(o::Node, x::Symbol, val) = setproperty!(getfield(o, :props), x, val)

# #-----------------------------------------------------------------------------# Edge
# struct Edge
#     source::Int
#     target::Int
#     props::Config
# end
# Edge(src::Integer, tgt::Integer; kw...) = Edge(src, tgt, Config(kw))
# Edge(src::Integer, tgt::Integer, txt::String) = Edge(src, tgt, JSON3.read(txt, Config))
# function Base.show(io::IO, o::Edge)
#     props = getfield(o, :props)
#     printstyled(io, "Edge $(getfield(o, :source)) → $(getfield(o, :target))", color=:light_cyan)
#     delete_empty!(props)
#     print_props(io, props)
# end
# Base.getproperty(o::Edge, x::Symbol) = getfield(o, :props)[x]
# Base.setproperty!(o::Edge, x::Symbol, val) = setproperty!(getfield(o, :props), x, val)


# #-----------------------------------------------------------------------------# DB
# struct DB
#     sqlitedb::SQLite.DB

#     function DB(file::String = ":memory:")
#         db = SQLite.DB(file)
#         foreach(x -> execute(db, x), [
#             "CREATE TABLE IF NOT EXISTS nodes (
#                 id INTEGER NOT NULL UNIQUE,
#                 props TEXT,
#                 UNIQUE(id) ON CONFLICT REPLACE
#             );",
#             "CREATE INDEX IF NOT EXISTS id_idx ON nodes(id);",
#             "CREATE TABLE IF NOT EXISTS edges (
#                 source INTEGER,
#                 target INTEGER,
#                 props  TEXT,
#                 UNIQUE(source, target) ON CONFLICT REPLACE,
#                 FOREIGN KEY(source) REFERENCES nodes(id),
#                 FOREIGN KEY(target) REFERENCES nodes(id)
#             );",
#             "CREATE INDEX IF NOT EXISTS source_idx ON edges(source);",
#             "CREATE INDEX IF NOT EXISTS target_idx ON edges(target);"
#         ])
#         new(db)
#     end
# end
# function Base.show(io::IO, db::DB)
#     print(io, "SQLiteGraph.DB(\"$(db.sqlitedb.file)\") ($(n_nodes(db)) nodes, $(n_edges(db)) edges)")
# end

# execute(db::DB, args...; kw...) = execute(db.sqlitedb, args...; kw...)

# n_nodes(db::DB) = single_result_execute(db, "SELECT Count(*) FROM nodes")
# n_edges(db::DB) = single_result_execute(db, "SELECT Count(*) FROM edges")

# init!(db::DB, n::Integer) = (foreach(id -> setindex!(db, nothing, id), 1:n); db)

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
