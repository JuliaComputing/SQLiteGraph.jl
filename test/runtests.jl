using SQLiteGraph
using Test
using JSON3

#-----------------------------------------------------------------------------# setup
db = DB()

#-----------------------------------------------------------------------------# Nodes
@testset "Nodes" begin
    @testset "Round Trips" begin
        for n in [
                Node(1),
                Node(2, "lab"),
                Node(3, "lab1", "lab2"),
                Node(4, "lab"; x=1),
                Node(5, "lab1", "lab2"; x=1, y=2)
            ]
            insert!(db, n)
            @test db[n.id] == n
            @test_throws Exception insert!(db, n)
        end
    end
    @testset "replace!" begin
        replace!(db, Node(1, "lab"))
        @test db[1].labels == ["lab"]
    end
    @testset "simple query" begin
        q = db[:]
        for (i,n) in enumerate(q)
            @test n.id == i
        end
        @test length(collect(db[:])) == 5
    end
end

#-----------------------------------------------------------------------------# Edges
@testset "Edges" begin
    @testset "Round Trips" begin
        for e in [
                Edge(1,2,"type"),
                Edge(1,3,"type"; x=1),
                Edge(1,4,"type 2"; x=1,y=2,z=3)
            ]
            insert!(db, e)
            @test db[e.source, e.target, e.type] == e
            @test_throws Exception insert!(db, e)
        end
    end
    @testset "replace!" begin
        replace!(db, Edge(1,2,"type"; x=1))
        @test db[1,2,"type"].props.x == 1
    end
    @testset "simple query" begin
        @test db[1,2,"type"] == Edge(1,2,"type"; x=1)
        @test length(collect(db[1,2,:])) == 1
        @test length(collect(db[1,:,"type"])) == 2
        @test length(collect(db[:,2,"type"])) == 1
        @test length(collect(db[:,:,"type"])) == 2
        @test length(collect(db[:, 4, :])) == 1
        @test length(collect(db[:,:,"type"])) == 2
        @test length(collect(db[:,:,:])) == 3
    end
end
