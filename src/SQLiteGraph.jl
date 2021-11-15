module SQLiteGraph

using SQLite: SQLite
import DBInterface: execute
using JSON3: JSON3

export DB, Node, Edge

#-----------------------------------------------------------------------------# utils 
read_sql(fn::String) = read(joinpath(@__DIR__, "sql", fn), String)

function single_result_execute(db, stmt, args...) 
    ex = execute(db, stmt, args...)
    isempty(ex) ? nothing : values(first(ex))[1]
end

#-----------------------------------------------------------------------------# DB
"""
    SimpleGraph.DB(file = ":memory")

Create a graph database (in memory by default).  Edge and node properties are saved in the database 
as text (`JSON3.write(props)`).

### Interal Table Structure

- `nodes`
  - `id INTEGER NOT NULL UNIQUE`
  - `props TEXT` (JSON.write)
- `edges`
  - `source INTEGER`
  - `target INTEGER`
  - `props TEXT` (JSON.write)
"""
struct DB
    sqlitedb::SQLite.DB

    function DB(file = ":memory:")
        db = SQLite.DB(file)
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
        new(db)
    end
end
function Base.show(io::IO, db::DB) 
    print(io, "SimpleGraphDB(\"$(db.sqlitedb.file)\") ($(n_nodes(db)) nodes, $(n_edges(db)) edges)")
end

execute(db::DB, args...; kw...) = execute(db.sqlitedb, args...; kw...)

n_nodes(db::DB) = single_result_execute(db, "SELECT Count(*) FROM nodes")
n_edges(db::DB) = single_result_execute(db, "SELECT Count(*) FROM edges")

Base.length(db::DB) = n_nodes(db)
Base.lastindex(db::DB) = length(db)

init!(db::DB, n) = (foreach(id -> setindex!(db, nothing, id), 1:n); db)


#-----------------------------------------------------------------------------# ReadAs 
struct ReadAs{T}
    db::DB 
end
ReadAs(db::DB, T::DataType=Dict{String,Any}) = ReadAs{T}(db)
Base.setindex!(r::ReadAs, args...) = setindex!(r.db, args...)
Base.getindex(r::ReadAs{T}, args...) where {T} = (res=r[args...]; isnothing(res) ? res : JSON3.read(res, T))


#-----------------------------------------------------------------------------# set/get node(s)
function Base.setindex!(db::DB, props, id::Integer)
    execute(db, "INSERT INTO nodes VALUES(?, json(?))", (id, JSON3.write(props)))
    db
end
function Base.getindex(db::DB, id::Integer)
    res = single_result_execute(db, "SELECT props FROM nodes WHERE id = ?", (id,))
    isnothing(res) ? throw(BoundsError(db, id)) : res
end

#-----------------------------------------------------------------------------# set/get edge(s)
function Base.setindex!(db::DB, props, i::Integer, j::Integer)
    execute(db, "INSERT INTO edges VALUES(?, ?, json(?))", (i, j, JSON3.write(props)))
    db
end
function Base.getindex(db::DB, i::Integer, j::Integer) 
    single_result_execute(db, "SELECT props FROM edges WHERE source = ? AND target = ? ", (i,j))
end

end
