using SQLiteGraph
using Test
using JSON3

@testset "SQLiteGraph.jl" begin
    db = DB()
    @testset "empty DB" begin 
        @test length(db) == 0 
        @test size(db) == (nodes=0, edges=0)
        @test_throws BoundsError db[5]
        @test isnothing(db[1,2])
    end
    @testset "setindex! & getindex" begin
        db[1] = (x=1, y=2)
        db[2] = (x=1, y=3)
        db[1,2] = (a=1, b=2)
        @test db[1] isa Node{String}
        @test db[2] isa Node{String}
        @test db[1,2] isa Edge{String}
        @testset "getindex Range" begin 
            @test db[1:2] isa Vector{Node{String}}
            @test db[1:2][1] == Node(1, JSON3.write((x=1,y=2)))
            @test db[1:2][2] == Node(2, JSON3.write((x=1,y=3)))
            @test db[1:2,2] == [Edge(1,2,JSON3.write((a=1,b=2)))]
        end
    end
end
