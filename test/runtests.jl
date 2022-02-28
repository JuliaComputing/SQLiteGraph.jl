using SQLiteGraph
using Test
using JSON3

@testset "SQLiteGraph.jl" begin
    db = DB()

    n1 = Node(1, "label 1", "label 2"; prop1=1, prop2=2)
    n1_2 = Node(1, "label 3", prop3=3)
    n2 = Node(2)

    @testset "Adding Nodes" begin

        push!(db, n1)
        @test db[1] == n1
        @test_throws Exception push!(db, n1)


        push!(db, n1_2; upsert=true)
        @test db[1] == n1_2
    end
    @testset "Adding Edges" begin
        push!(db, Node(2))
        e1 = Edge(1, 2, "type")
        push!(db, e1)
        @test e1 == db[1,2,"type"]
    end
    @testset "Querying Nodes" begin
        @test length(collect(db[:])) == 2
        @test db[1] == n1_2
    end
end
