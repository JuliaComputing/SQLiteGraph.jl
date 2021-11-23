using SQLiteGraph
using Test
using JSON3

@testset "SQLiteGraph.jl" begin
    db = DB()
    node1 = (x=1, y=2)
    node2 = (x=1, y=3)
    edge1 = (a=1, b=2)
    edge2 = (a=3, b=4)

    @testset "empty DB" begin 
        @test length(db) == 0 
        @test size(db) == (nodes=0, edges=0)
        @test_throws BoundsError db[5]
        @test isnothing(db[1,2])
    end
    @testset "setindex! & getindex" begin
        db[1] = node1
        db[2] = node2
        db[1,2] = edge1
        db[2,1] = edge2
        @test db[1] isa Node{String}
        @test db[2] isa Node{String}
        @test db[1,2] isa Edge{String}
        @testset "getindex Range" begin 
            @test collect(db[1:2]) isa Vector{Node{String}}
            q = collect(db[1:2])
            @test q[1] == Node(1, JSON3.write(node1))
            @test q[2] == Node(2, JSON3.write(node2))
            @test first(db[1:2,2]) == Edge(1,2,JSON3.write(edge1))
        end
    end
    @testset "find_nodes / find_edges" begin 
        res = collect(find_nodes(db, y=2))
        @test length(res) == 1 
        @test res[1] == Node(1, JSON3.write(node1))

        res = collect(find_nodes(db, r"y"))
        @test length(res) == 2
        @test res[1] == Node(1, JSON3.write(node1))
        @test res[2] == Node(2, JSON3.write(node2))

        res = collect(find_edges(db, a=1))
        @test length(res) == 1
        @test res[1] == Edge(1,2, JSON3.write(edge1))

        res = collect(find_edges(db, r"a"))
        @test length(res) == 2
        @test res[1] == Edge(1,2, JSON3.write(edge1))
        @test res[2] == Edge(2,1, JSON3.write(edge2))

    end
end
